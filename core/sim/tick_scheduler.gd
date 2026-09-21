class_name TickScheduler
extends RefCounted

## The fixed simulation clock: 20 logic ticks per second, decoupled from framerate.
##
## Gameplay never reads delta time. It reads ticks. A machine running at 30fps and one
## running at 144fps simulate the same shift, which is what lets the bot player, the
## headless integration tests and five networked peers agree about what happened.

signal ticked(tick: int)

const TICKS_PER_SECOND: int = 20
const SECONDS_PER_TICK: float = 1.0 / float(TICKS_PER_SECOND)
const USEC_PER_TICK: int = 1_000_000 / TICKS_PER_SECOND

## Guards against the spiral of death: after a long stall, drop the backlog instead of
## trying to simulate it all in one frame.
const MAX_CATCHUP_TICKS: int = 8

var _tick: int = 0
## Accumulated in integer microseconds, not float seconds: summing 1/144 sixty thousand
## times drifts, and a clock that drifts is a clock that desyncs.
var _accumulator_usec: int = 0
var _time_scale: float = 1.0
var _paused: bool = false
var _dropped_ticks: int = 0


func current_tick() -> int:
	return _tick


## In-simulation seconds elapsed. Derived from the tick count rather than accumulated
## float time, so it cannot drift.
func elapsed_seconds() -> float:
	return float(_tick) * SECONDS_PER_TICK


func time_scale() -> float:
	return _time_scale


func set_time_scale(scale: float) -> void:
	_time_scale = maxf(0.0, scale)


func is_paused() -> bool:
	return _paused


func set_paused(paused: bool) -> void:
	_paused = paused


## Ticks dropped to catch-up clamping since the last reset. Non-zero means the host
## stalled; the integration tests assert it stays at zero.
func dropped_ticks() -> int:
	return _dropped_ticks


## Feed real frame time in. Returns how many ticks ran.
func advance(delta_seconds: float) -> int:
	if _paused or _time_scale <= 0.0:
		return 0
	_accumulator_usec += int(round(delta_seconds * _time_scale * 1_000_000.0))
	var ran: int = 0
	while _accumulator_usec >= USEC_PER_TICK:
		_accumulator_usec -= USEC_PER_TICK
		ran += 1
		if ran >= MAX_CATCHUP_TICKS:
			var backlog: int = _accumulator_usec / USEC_PER_TICK
			_dropped_ticks += backlog
			_accumulator_usec -= backlog * USEC_PER_TICK
			break
	for _index: int in range(ran):
		_tick += 1
		ticked.emit(_tick)
	return ran


## Runs exactly [param count] ticks, ignoring wall-clock time. Tests and the bot player
## use this to simulate a full day in milliseconds.
func advance_ticks(count: int) -> void:
	for _index: int in range(maxi(0, count)):
		_tick += 1
		ticked.emit(_tick)


func snapshot() -> Dictionary:
	return {"tick": _tick, "time_scale": _time_scale}


func restore(snapshot_data: Dictionary) -> void:
	_tick = int(snapshot_data.get("tick", 0))
	_time_scale = float(snapshot_data.get("time_scale", 1.0))
	_accumulator_usec = 0
	_dropped_ticks = 0
