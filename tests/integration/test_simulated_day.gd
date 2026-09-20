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


func test_a_careless_player_loses_more_than_a_careful_one() -> void:
	# Scrutiny has to pay for itself, or the whole thesis collapses.
	var careless: Dictionary = BotPlayer.new(_shop(21), BotPlayer.Policy.CARELESS).play(3)
	var careful: Dictionary = BotPlayer.new(_shop(21), BotPlayer.Policy.PARANOID).play(3)
	(
		assert_float(float(careful["final_reputation"]))
		. override_failure_message(
			(
				"careless reputation %.2f, careful %.2f"
				% [careless["final_reputation"], careful["final_reputation"]]
			)
		)
		. is_greater(float(careless["final_reputation"]))
	)


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
