extends GdUnitTestSuite

## The Phase 2 gate: the bot completes a simulated day. Beyond that, these assert the
## properties a shift must have — never idle, never unwinnable, never unfair.

var registry: ContentRegistry
var bus: EventBus


func before() -> void:
	registry = ContentRegistry.new()
	bus = EventBus.new()
	var loader := ContentLoader.new(registry)
	loader.load_all("res://content", "res://tests/no_mods")


func _shop(seed_value: int, players: int = 3, preset: String = "standard") -> Shop:
	var rng := SeededRng.new(seed_value)
	var shop := Shop.new(registry, EventBus.new(), rng, Director.Profile.preset(preset), players)
	shop.open_for_business(600.0)
	return shop


func test_the_bot_completes_a_simulated_day() -> void:
	var shop: Shop = _shop(1)
	var bot := BotPlayer.new(shop)
	var report: Dictionary = bot.play(1)
	assert_int(int(report["days"])).is_equal(1)
	assert_int(int(report["actions"])).is_greater(20)
	assert_int(int(report["soft_lock_ticks"])).is_equal(0)


func test_a_day_produces_work_in_every_loop() -> void:
	var shop: Shop = _shop(7)
	var bot := BotPlayer.new(shop)
	var report: Dictionary = bot.play(1)
	var summary: Dictionary = (report["summaries"] as Array)[0]
	assert_int(int(summary["served"])).override_failure_message(str(summary)).is_greater(0)
	assert_int(int((summary["kitchen"] as Dictionary)["served"])).is_greater(0)
	assert_int(int((summary["library"] as Dictionary)["awaiting_check"])).is_greater_equal(0)


func test_the_simulation_is_deterministic_for_a_seed() -> void:
	# Same seed, same day, same outcome — which is what makes a bug report reproducible
	# and a desync debuggable.
	var first: Dictionary = BotPlayer.new(_shop(99)).play(1)
	var second: Dictionary = BotPlayer.new(_shop(99)).play(1)
	assert_float(float(first["final_money"])).is_equal_approx(float(second["final_money"]), 0.0001)
	assert_int(int(first["actions"])).is_equal(int(second["actions"]))


func test_different_seeds_produce_different_days() -> void:
	var first: Dictionary = BotPlayer.new(_shop(3)).play(1)
	var second: Dictionary = BotPlayer.new(_shop(4)).play(1)
	assert_float(float(first["final_money"])).is_not_equal(float(second["final_money"]))


func test_nobody_stands_idle_while_work_waits() -> void:
	# Pillar 2, as an assertion: a player with nothing to do is a bug.
	for seed_value: int in [11, 12, 13]:
		var report: Dictionary = BotPlayer.new(_shop(seed_value)).play(1)
		(
			assert_int(int(report["soft_lock_ticks"]))
			. override_failure_message("seed %d left a player idle with work waiting" % seed_value)
			. is_equal(0)
		)


func test_a_careless_player_misses_forgeries_a_careful_one_catches() -> void:
	# Scrutiny has to pay for itself, or the whole thesis collapses. Measured as missed
	# forgeries rather than as reputation, and aggregated across seeds: any single day
	# can go well for a careless player.
	var careless: Dictionary = _policy_tally(BotPlayer.Policy.CARELESS, [21, 22, 23])
	var careful: Dictionary = _policy_tally(BotPlayer.Policy.PARANOID, [21, 22, 23])

	(
		assert_int(int(careful["forged"]))
		. override_failure_message(
			"no forgeries reached the counter at all; the director is not sending any"
		)
		. is_greater(0)
	)
	(
		assert_int(int(careful["missed"]))
		. override_failure_message(
			(
				"careful missed %d of %d, careless missed %d of %d"
				% [careful["missed"], careful["forged"], careless["missed"], careless["forged"]]
			)
		)
		. is_less(int(careless["missed"]))
	)
	assert_int(int(careless["strikes"])).is_greater(int(careful["strikes"]))
	# Deliberately not asserted here: that the exhaustive checker ends with better
	# reputation than the careless one. It does not, and the design says it should not --
	# checking everything is a mistake, and a shop that serves forty people a day is worse
	# regarded than one that serves four hundred badly. The claim that reputation is built
	# by judgement rather than by volume belongs to triage, and lives in
	# test_triage_beats_carelessness_on_the_books.


func test_scrutiny_costs_throughput() -> void:
	# The load-bearing claim: a shift contains far more checkable material than checkable
	# time. Checking everything has to cost customers, or "scrutiny is a budget" is a
	# slogan rather than a mechanic.
	var seeds: Array = [21, 22, 23]
	var careless: Dictionary = _policy_tally(BotPlayer.Policy.CARELESS, seeds, 4)
	var triage: Dictionary = _policy_tally(BotPlayer.Policy.BALANCED, seeds, 4)
	var exhaustive: Dictionary = _policy_tally(BotPlayer.Policy.PARANOID, seeds, 4)

	(
		assert_int(int(exhaustive["walked_out"]))
		. override_failure_message(
			(
				"walked out -- careless %d, triage %d, exhaustive %d: checking everything is free"
				% [careless["walked_out"], triage["walked_out"], exhaustive["walked_out"]]
			)
		)
		. is_greater(int(careless["walked_out"]))
	)
	assert_int(int(triage["walked_out"])).is_greater(int(careless["walked_out"]))
	# And it has to buy something. The measure is the rate, not the count: a careless
	# player serves more people and therefore sees more forgeries, so comparing totals
	# would flatter them for being fast.
	(
		assert_float(_miss_rate(exhaustive))
		. override_failure_message(
			(
				"miss rate -- careless %.2f (%d/%d), exhaustive %.2f (%d/%d)"
				% [
					_miss_rate(careless),
					careless["missed"],
					careless["forged"],
					_miss_rate(exhaustive),
					exhaustive["missed"],
					exhaustive["forged"],
				]
			)
		)
		. is_less(_miss_rate(careless))
	)


## Missed forgeries as a fraction of the forgeries that reached the counter.
func _miss_rate(tally: Dictionary) -> float:
	var seen: int = int(tally["forged"])
	return 0.0 if seen == 0 else float(tally["missed"]) / float(seen)


func test_triage_beats_carelessness_on_the_books() -> void:
	var seeds: Array = [21, 22, 23]
	var careless: Dictionary = _policy_tally(BotPlayer.Policy.CARELESS, seeds)
	var triage: Dictionary = _policy_tally(BotPlayer.Policy.BALANCED, seeds)
	(
		assert_float(float(triage["net_worth"]))
		. override_failure_message(
			"careless %.0f, triage %.0f" % [careless["net_worth"], triage["net_worth"]]
		)
		. is_greater(float(careless["net_worth"]))
	)
	assert_float(float(triage["reputation"])).is_greater(float(careless["reputation"]))


## Plays a policy across seeds and reports what it cost and what it caught. The tally is
## a Dictionary because GDScript lambdas capture locals by value.
func _policy_tally(policy: BotPlayer.Policy, seeds: Array, days: int = 5) -> Dictionary:
	var totals: Dictionary = {
		"forged": 0,
		"missed": 0,
		"strikes": 0,
		"reputation": 0.0,
		"net_worth": 0.0,
		"served": 0,
		"walked_out": 0,
	}
	for seed_value: int in seeds:
		var bus := EventBus.new()
		var shop := Shop.new(
			registry, bus, SeededRng.new(seed_value), Director.Profile.preset("standard"), 3
		)
		shop.open_for_business(600.0)
		bus.subscribe(
			EventCatalog.VERIFICATION_RESOLVED,
			func(payload: Dictionary) -> void:
				if not bool(payload.get("was_forged", false)):
					return
				totals["forged"] = int(totals["forged"]) + 1
				if int(payload.get("outcome", 0)) == Encounter.Outcome.WRONG_APPROVED:
					totals["missed"] = int(totals["missed"]) + 1,
			"test"
		)
		bus.subscribe(
			EventCatalog.STRIKE_ISSUED,
			func(_payload: Dictionary) -> void: totals["strikes"] = int(totals["strikes"]) + 1,
			"test"
		)
		var report: Dictionary = BotPlayer.new(shop, policy).play(days)
		totals["reputation"] = float(totals["reputation"]) + float(report["final_reputation"])
		# Cash alone is misleading: money in cardboard is still money, and a shop that
		# converted its till into stock has not lost anything yet.
		totals["net_worth"] = (
			float(totals["net_worth"]) + float(report["final_money"]) + shop.card_case.case_value()
		)
		totals["served"] = int(totals["served"]) + shop.served_today
		totals["walked_out"] = int(totals["walked_out"]) + shop.walked_out
	return totals


func test_solo_play_is_viable() -> void:
	var report: Dictionary = BotPlayer.new(_shop(31, 1)).play(2)
	assert_int(int(report["soft_lock_ticks"])).is_equal(0)
	assert_bool(bool(report["insolvent"])).is_false()


func test_five_players_are_not_starved_of_work() -> void:
	var shop: Shop = _shop(41, 5)
	var report: Dictionary = BotPlayer.new(shop).play(1)
	assert_int(int(report["actions"])).is_greater(40)


func test_difficulty_presets_change_the_shift_not_the_rules() -> void:
	var relaxed: Dictionary = (
		BotPlayer.new(_shop(51, 3, "relaxed"), BotPlayer.Policy.CARELESS).play(2)
	)
	var brutal: Dictionary = BotPlayer.new(_shop(51, 3, "brutal"), BotPlayer.Policy.CARELESS).play(
		2
	)
	assert_float(float(brutal["final_reputation"])).is_less_equal(
		float(relaxed["final_reputation"])
	)


func test_telemetry_answers_balance_questions() -> void:
	var shop: Shop = _shop(61)
	var log := RunLog.new(shop.bus, 61, "standard", 3)
	var bot := BotPlayer.new(shop, BotPlayer.Policy.BALANCED, log)
	bot.play(1)
	var summary: Dictionary = log.summary()
	assert_int(int((summary["counters"] as Dictionary).get("verification_resolved", 0))).is_greater(
		0
	)
	assert_int(int(summary["samples"])).is_greater(10)
	assert_bool((summary["verdicts"] as Dictionary).is_empty()).is_false()
