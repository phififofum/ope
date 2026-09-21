extends GdUnitTestSuite

## Phase 5's gate, at a size CI can afford: the bot runs a campaign at every player
## count without soft-locking or stalling, and delegation behaves the way the design
## insists it must -- converting work into supervision rather than removing it.
##
## The full sweep (every count, every preset, fifty seeds) is tools/nightly_bot.sh.

const CAMPAIGN_DAYS: int = 10

var registry: ContentRegistry


func before() -> void:
	registry = ContentRegistry.new()
	ContentLoader.new(registry).load_all("res://content", "res://tests/no_mods")


func _run(
	players: int, seed_value: int, preset: String = "standard", days: int = CAMPAIGN_DAYS
) -> Dictionary:
	var shop := Shop.new(
		registry,
		EventBus.new(),
		SeededRng.new(seed_value),
		Director.Profile.preset(preset),
		players
	)
	shop.open_for_business(600.0)
	var report: Dictionary = BotPlayer.new(shop).play(days)
	report["shop"] = shop
	return report


func test_every_player_count_completes_a_campaign_stretch() -> void:
	for players: int in [1, 2, 3, 4, 5]:
		var report: Dictionary = _run(players, 500 + players)
		(
			assert_int(int(report["days"]))
			. override_failure_message(
				"%d players did not finish %d days" % [players, CAMPAIGN_DAYS]
			)
			. is_equal(CAMPAIGN_DAYS)
		)
		(
			assert_int(int(report["soft_lock_ticks"]))
			. override_failure_message(
				"%d players left a free pair of hands with unreachable work" % players
			)
			. is_equal(0)
		)


func test_progression_pace_is_comparable_across_player_counts() -> void:
	# A trio and a solo player should reach the same place in comparable time. The
	# measure is licences taken, because that is what actually gates the game.
	var paces: Array[int] = []
	for players: int in [1, 3, 5]:
		var report: Dictionary = _run(players, 700 + players)
		paces.append((report["shop"] as Shop).economy.licences.size())
	var lowest: int = paces.min()
	var highest: int = paces.max()
	(
		assert_int(highest - lowest)
		. override_failure_message("licences held at 1, 3 and 5 players: %s" % [paces])
		. is_less_equal(2)
	)


func test_every_difficulty_preset_is_survivable_and_different() -> void:
	var relaxed: Dictionary = _run(3, 801, "relaxed", 6)
	var brutal: Dictionary = _run(3, 801, "brutal", 6)
	assert_int(int(relaxed["soft_lock_ticks"])).is_equal(0)
	assert_int(int(brutal["soft_lock_ticks"])).is_equal(0)
	assert_float(float(brutal["final_reputation"])).is_not_equal(float(relaxed["final_reputation"]))


func test_staff_convert_work_into_supervision_rather_than_removing_it() -> void:
	# Driven directly rather than through the bot's economy: this is about what
	# delegation does, not about whether a bot could afford it this week.
	var shop := Shop.new(
		registry, EventBus.new(), SeededRng.new(31337), Director.Profile.preset("standard"), 3
	)
	shop.open_for_business(20000.0)
	for role_id: StringName in [&"base:counter_staff", &"base:kitchen_staff"]:
		var applicant: StaffSystem.Employee = shop.interview(role_id)
		shop.staff.grant_permission(applicant, "handle_age_restricted")
		shop.staff.hire(applicant, shop.economy)
	assert_int(shop.staff.employees.size()).is_equal(2)

	var absorbed: float = 0.0
	for _shift: int in range(20):
		absorbed += float(shop.staff.work_shift(0.5, shop.economy)["tasks_absorbed"])
		shop.staff.advance_day(shop.staff.mistakes.size() + 1, shop.economy)

	# They take work off your hands...
	assert_float(absorbed).is_greater(0.0)
	# ...and hand you back something to supervise. Mistakes are recorded, never reported.
	(
		assert_int(shop.staff.mistakes.size())
		. override_failure_message(
			"twenty shifts without a single mistake; the error model is not running"
		)
		. is_greater(0)
	)

	var unsurfaced_before: float = shop.staff.unsurfaced_cost()
	(
		assert_float(unsurfaced_before)
		. override_failure_message(
			"every mistake surfaced by itself; nothing was left for the audit to find"
		)
		. is_greater(0.0)
	)

	# Reviewing is how you find out. It costs time, and it only finds what you look for.
	var found: Array = shop.staff.review("review", 1.0)
	assert_int(found.size()).is_greater(0)
	assert_float(shop.staff.unsurfaced_cost()).is_less(unsurfaced_before)


func test_no_configuration_of_staff_runs_the_shop_alone() -> void:
	# The guardrail: maximum coverage is partial, and the remainder is oversight that
	# cannot be delegated.
	var total_coverage: float = 0.0
	for role: ContentDefinition in registry.by_type(&"staff_role"):
		(
			assert_float(role.get_number("coverage"))
			. override_failure_message("%s can absorb its whole job" % role.id)
			. is_less(1.0)
		)
		total_coverage += role.get_number("coverage")
	assert_float(total_coverage / float(registry.count_of(&"staff_role"))).is_less(
		StaffSystem.MAX_COVERAGE + 0.01
	)


func test_a_candidate_can_lie_on_their_application() -> void:
	# Hiring is a verification encounter wearing a different hat.
	var shop := Shop.new(
		registry, EventBus.new(), SeededRng.new(4242), Director.Profile.preset("standard"), 3
	)
	var liars: int = 0
	for _attempt: int in range(40):
		var applicant: StaffSystem.Employee = shop.interview(&"base:counter_staff")
		if applicant.lied_on_application():
			liars += 1
	(
		assert_int(liars)
		. override_failure_message(
			"nobody ever exaggerates their experience, so checking references is free"
		)
		. is_greater(0)
	)
	(
		assert_int(liars)
		. override_failure_message("everybody lies, which makes the check pointless")
		. is_less(40)
	)


func test_the_campaign_asks_a_different_question_in_each_act() -> void:
	var shop := Shop.new(
		registry, EventBus.new(), SeededRng.new(1), Director.Profile.preset("standard"), 3
	)
	var questions: Array[String] = []
	for day: int in [1, 20, 60, 100, 200]:
		shop.day = day
		questions.append(shop.act_question())
	assert_int(questions.size()).is_equal(5)
	for index: int in range(1, questions.size()):
		assert_str(questions[index]).is_not_equal(questions[index - 1])
