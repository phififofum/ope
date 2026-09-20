class_name Director
extends RefCounted

## Paces the shift.
##
## Encounters are scheduled, not rolled. Randomness produces long flat stretches and cruel
## clusters in equal measure; a budget of suspicious encounters placed where they land
## hardest produces a shift with a shape.
##
## Everything here is data-driven, so "brutal mode" is a JSON file rather than a fork.


class Profile:
	extends RefCounted
	var name: String = "standard"
	var suspicious_per_shift: int = 3
	## Ticks between arrivals at one player. ~21 seconds, which over a 25-minute day is a
	## busy-but-possible room rather than a stadium.
	var arrival_interval_ticks: int = 420
	var max_tier: int = 2
	var forgery_difficulty_bias: float = 0.0
	var min_gap_between_hard_ticks: int = 200
	var idle_prod_ticks: int = 900
	var adaptive: bool = true

	static func preset(preset_name: String) -> Profile:
		var profile := Profile.new()
		profile.name = preset_name
		match preset_name:
			"relaxed":
				profile.suspicious_per_shift = 1
				profile.arrival_interval_ticks = 620
				profile.max_tier = 1
				profile.forgery_difficulty_bias = -0.5
			"tight":
				profile.suspicious_per_shift = 5
				profile.arrival_interval_ticks = 320
				profile.max_tier = 3
				profile.forgery_difficulty_bias = 0.3
			"brutal":
				profile.suspicious_per_shift = 7
				profile.arrival_interval_ticks = 240
				profile.max_tier = 4
				profile.forgery_difficulty_bias = 0.8
				profile.min_gap_between_hard_ticks = 120
		return profile


var profile: Profile
var rng: SeededRng

var _scheduled: Array[int] = []
var _last_hard_tick: int = -10000
var _hard_tick_before_last: int = -10000
var _last_arrival_tick: int = 0
var _correct_streak: int = 0
var _error_streak: int = 0


func _init(p_profile: Profile, p_rng: SeededRng) -> void:
	profile = p_profile
	rng = p_rng


## Lays out this shift's suspicious encounters in advance, biased towards the moments
## they will land hardest: during a rush, just after a delivery, at shift change.
func plan_shift(shift_length_ticks: int, _player_count: int) -> Array[int]:
	_scheduled.clear()
	# Flat per shift, not per player: the suspicious encounters are the content, and
	# everyone should see them. More players means more eyes, not more encounters each.
	var budget: int = profile.suspicious_per_shift
	var pressure_windows: Array[float] = [0.25, 0.55, 0.8]
	for index: int in range(budget):
		var window: float = pressure_windows[index % pressure_windows.size()]
		var jitter: float = rng.stream(SeededRng.SPAWN).randf_range(-0.08, 0.08)
		_scheduled.append(int(clampf(window + jitter, 0.05, 0.95) * float(shift_length_ticks)))
	_scheduled.sort()
	_spread_out()
	return _scheduled.duplicate()


## Should someone arrive this tick? Sub-linear in player count: more players should mean
## more comfort as well as more work.
## [param draw] is everything the shop has done to be worth visiting -- a wall of cards
## people want to look at, mostly. It shortens the gap between arrivals, which is the only
## honest way for a display case to pay for itself.
func should_spawn(
	current_tick: int, player_count: int, active_load: int, draw: float = 0.0
) -> bool:
	var interval: float = (
		float(profile.arrival_interval_ticks)
		/ ((1.0 + 0.55 * float(player_count - 1)) * (1.0 + clampf(draw, 0.0, 1.5)))
	)
	if active_load > player_count * 2:
		interval *= 1.6  # load-aware: if everyone is buried, hold off
	if current_tick - _last_arrival_tick < int(interval):
		return false
	_last_arrival_tick = current_tick
	return true


## Is this the tick a suspicious encounter was scheduled for? Never two hard encounters
## back to back without a breath between.
func should_be_suspicious(current_tick: int) -> bool:
	for scheduled_tick: int in _scheduled:
		if current_tick >= scheduled_tick:
			if current_tick - _last_hard_tick < profile.min_gap_between_hard_ticks:
				continue
			_scheduled.erase(scheduled_tick)
			_hard_tick_before_last = _last_hard_tick
			_last_hard_tick = current_tick
			return true
	return false


## Hands a scheduled encounter back, unspent.
##
## A suspicious slot that could not be filled -- nothing wrong with the document that
## turned up would have been catchable -- must not be consumed, or a shift quietly loses
## most of its content and carelessness stops costing anything.
func return_slot(current_tick: int) -> void:
	_scheduled.append(current_tick + 40)
	_scheduled.sort()
	_last_hard_tick = _hard_tick_before_last


## The room has been quiet for too long: send something. A player with nothing to do is
## a bug.
func should_prod(current_tick: int) -> bool:
	return current_tick - _last_arrival_tick > profile.idle_prod_ticks


## Difficulty adapts and the game never says so. A long correct streak earns a harder
## vector; three errors quietly earn an easier one.
func record_outcome(correct: bool) -> void:
	if correct:
		_correct_streak += 1
		_error_streak = 0
	else:
		_error_streak += 1
		_correct_streak = 0


## The tier of forgery to send next.
##
## [param toolkit_tier] is the best tool the player actually owns, and it is the ceiling.
## Difficulty advances by introducing vectors that are invisible until you own the
## instrument that reveals them -- not by sending vectors nobody can catch and calling it
## challenge.
func tier_for_next(toolkit_tier: int = 4) -> int:
	var tier: int = mini(profile.max_tier, toolkit_tier)
	if not profile.adaptive:
		return maxi(0, tier)
	# Adapts quietly, and the game never announces it.
	if _correct_streak >= 6:
		tier = mini(mini(4, toolkit_tier), tier + 1)
	if _error_streak >= 3:
		tier = maxi(0, tier - 1)
	return maxi(0, tier)


func streaks() -> Dictionary:
	return {"correct": _correct_streak, "errors": _error_streak}


func _spread_out() -> void:
	for index: int in range(1, _scheduled.size()):
		if _scheduled[index] - _scheduled[index - 1] < profile.min_gap_between_hard_ticks:
			_scheduled[index] = _scheduled[index - 1] + profile.min_gap_between_hard_ticks
