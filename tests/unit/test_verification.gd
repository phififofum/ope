extends GdUnitTestSuite

## The primary loop. These tests encode the design's fairness promises as assertions,
## because they are the difference between tension and frustration.

const TODAY: int = 20000

var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng
var engine: VerificationEngine
var people: PersonFactory


func before_test() -> void:
	registry = ContentRegistry.new()
	bus = EventBus.new()
	rng = SeededRng.new(4242)
	var loader := ContentLoader.new(registry)
	loader.load_all("res://content", "res://tests/no_mods")
	engine = VerificationEngine.new(registry, bus, rng)
	engine.set_today(TODAY)
	people = PersonFactory.new(rng, TODAY)


func _all_tools() -> PackedStringArray:
	var ids: PackedStringArray = []
	for tool: ContentDefinition in registry.by_type(&"tool"):
		ids.append(String(tool.id))
	return ids


func _adult() -> Person:
	var person: Person = people.create_stranger(30, 45)
	return person


func test_a_genuine_id_for_an_adult_passes_every_check() -> void:
	var encounter: Encounter = engine.create(
		&"base:state_id_northvale",
		_adult(),
		PackedStringArray(["id_required", "age_restricted"]),
		false,
		4
	)
	var findings: Array = encounter.evaluate_with(engine.rules, _all_tools(), TODAY)
	assert_int(findings.size()).is_greater(0)
	for finding: RuleEngine.Finding in findings:
		(
			assert_bool(finding.failed())
			. override_failure_message("%s failed on a genuine document" % finding.rule_id)
			. is_false()
		)


func test_an_underage_customer_fails_the_age_rule_even_with_a_real_id() -> void:
	# The honest failure: nothing is forged, the person simply is not old enough.
	var teenager: Person = people.create_stranger(16, 17)
	var encounter: Encounter = engine.create(
		&"base:state_id_northvale",
		teenager,
		PackedStringArray(["id_required", "age_restricted", "alcohol"]),
		false,
		4
	)
	encounter.evaluate_with(engine.rules, _all_tools(), TODAY)
	assert_bool(encounter.has_blocking_failure()).is_true()
	assert_bool(encounter.is_forged()).is_false()


func test_a_forged_document_is_catchable_with_the_right_tool_and_invisible_without_it() -> void:
	var document: ContentDefinition = registry.get_definition(&"base:state_id_northvale")
	var vector: ContentDefinition = registry.get_definition(&"base:missing_uv_overlay")
	var person: Person = _adult()
	var artifact: Artifact = engine.forgeries.generate_genuine(document, person, TODAY)
	engine.forgeries.apply_vector(artifact, vector, person, TODAY)

	var encounter := Encounter.new()
	encounter.person = person
	encounter.artifacts.append(artifact)
	encounter.transaction_tags = PackedStringArray(["id_required"])

	# With the torch: caught.
	encounter.evaluate_with(engine.rules, PackedStringArray(["base:uv_torch"]), TODAY)
	assert_bool(encounter.has_blocking_failure()).is_true()

	# Owning the torch and not reaching for it: unchecked, not a pass. That is scrutiny
	# the player chose not to spend, and it is where misses come from.
	encounter.evaluate_with(
		engine.rules,
		PackedStringArray(["base:naked_eye"]),
		TODAY,
		PackedStringArray(["base:naked_eye", "base:uv_torch"])
	)
	assert_bool(encounter.has_blocking_failure()).is_false()
	assert_bool(encounter.has_unchecked_rule()).is_true()

	# Not owning it at all: not applicable. The director only sends forgeries the
	# current toolkit can catch, so this is not a gap the player can be blamed for.
	encounter.evaluate_with(engine.rules, PackedStringArray(["base:naked_eye"]), TODAY)
	assert_bool(encounter.has_unchecked_rule()).is_false()


func test_every_forged_encounter_is_either_catchable_or_refusable() -> void:
	# The fairness contract, checked across many seeds: the game never demands a coin
	# flip. Either a tool the player could own catches it, or declining resolves it.
	for seed_value: int in range(25):
		var local_rng := SeededRng.new(seed_value)
		var local_engine := VerificationEngine.new(registry, bus, local_rng)
		local_engine.set_today(TODAY)
		var factory := PersonFactory.new(local_rng, TODAY)
		var encounter: Encounter = local_engine.create(
			&"base:state_id_northvale",
			factory.create_stranger(25, 50),
			PackedStringArray(["id_required"]),
			true,
			4
		)
		assert_bool(encounter.is_forged()).is_true()
		var catchable: PackedStringArray = local_engine.detectable_vectors(encounter, _all_tools())
		(
			assert_array(catchable)
			. override_failure_message("seed %d produced an uncatchable forgery" % seed_value)
			. is_not_empty()
		)


func test_a_barcode_mismatch_needs_the_scanner() -> void:
	var document: ContentDefinition = registry.get_definition(&"base:state_id_northvale")
	var person: Person = _adult()
	var artifact: Artifact = engine.forgeries.generate_genuine(document, person, TODAY)
	engine.forgeries.apply_vector(
		artifact, registry.get_definition(&"base:barcode_mismatch"), person, TODAY
	)
	var encounter := Encounter.new()
	encounter.person = person
	encounter.artifacts.append(artifact)
	encounter.transaction_tags = PackedStringArray(["id_required"])

	encounter.evaluate_with(engine.rules, PackedStringArray(["base:barcode_scanner"]), TODAY)
	assert_bool(encounter.has_blocking_failure()).is_true()
	encounter.evaluate_with(engine.rules, PackedStringArray(["base:uv_torch"]), TODAY)
	assert_bool(encounter.has_blocking_failure()).is_false()


func test_approving_a_forgery_costs_far_more_than_declining_an_honest_customer() -> void:
	var forged: Encounter = engine.create(
		&"base:state_id_northvale", _adult(), PackedStringArray(["id_required"]), true, 4
	)
	var approved: Dictionary = engine.resolve(forged, Encounter.Verdict.APPROVE, _all_tools(), 100)
	var honest: Encounter = engine.create(
		&"base:state_id_northvale", _adult(), PackedStringArray(["id_required"]), false, 4
	)
	var declined: Dictionary = engine.resolve(honest, Encounter.Verdict.DECLINE, _all_tools(), 100)

	assert_float(float(approved["reputation_delta"])).is_less(float(declined["reputation_delta"]))
	assert_int(int(approved["outcome"])).is_equal(Encounter.Outcome.WRONG_APPROVED)


func test_declining_when_you_could_not_check_is_cheaper_than_declining_carelessly() -> void:
	var careless: Encounter = engine.create(
		&"base:state_id_northvale", _adult(), PackedStringArray(["id_required"]), false, 4
	)
	var careless_result: Dictionary = engine.resolve(
		careless, Encounter.Verdict.DECLINE, _all_tools(), 100
	)
	# Owned the tools, did not spend the seconds: the decline is cheap, because the
	# player knew what they did not check.
	var tool_gap: Encounter = engine.create(
		&"base:state_id_northvale", _adult(), PackedStringArray(["id_required"]), false, 4
	)
	var gap_result: Dictionary = engine.resolve(
		tool_gap,
		Encounter.Verdict.DECLINE,
		PackedStringArray(["base:naked_eye"]),
		100,
		_all_tools()
	)
	assert_float(float(gap_result["reputation_delta"])).is_greater(
		float(careless_result["reputation_delta"])
	)
	assert_int(int(gap_result["outcome"])).is_equal(Encounter.Outcome.OVERCAUTIOUS)


func test_refusing_a_fraudster_costs_nothing() -> void:
	var forged: Encounter = engine.create(
		&"base:state_id_northvale", _adult(), PackedStringArray(["id_required"]), true, 4
	)
	var result: Dictionary = engine.resolve(forged, Encounter.Verdict.DECLINE, _all_tools(), 100)
	assert_float(float(result["reputation_delta"])).is_equal_approx(0.0, 0.0001)
	assert_int(int(result["outcome"])).is_equal(Encounter.Outcome.CORRECT)


func test_behaviour_is_correlated_with_guilt_but_never_determines_it() -> void:
	# A player who convicts on nerves alone must be wrong often enough to learn.
	var nervous_honest: int = 0
	var calm_fraud: int = 0
	for index: int in range(120):
		var local_rng := SeededRng.new(index)
		var local_engine := VerificationEngine.new(registry, bus, local_rng)
		local_engine.set_today(TODAY)
		var factory := PersonFactory.new(local_rng, TODAY)
		var honest_person: Person = factory.create_stranger(30, 50)
		local_engine.create(
			&"base:state_id_northvale", honest_person, PackedStringArray(["id_required"]), false, 4
		)
		if honest_person.nervousness > 0.3:
			nervous_honest += 1
		var fraud_person: Person = factory.create_stranger(30, 50)
		local_engine.create(
			&"base:state_id_northvale", fraud_person, PackedStringArray(["id_required"]), true, 4
		)
		if fraud_person.nervousness < 0.5:
			calm_fraud += 1
	(
		assert_int(nervous_honest)
		. override_failure_message(
			"no honest customer was ever nervous; the signal has become determinative"
		)
		. is_greater(0)
	)
	(
		assert_int(calm_fraud)
		. override_failure_message(
			"no fraudster was ever calm; the signal has become determinative"
		)
		. is_greater(0)
	)


func test_inspection_costs_time_and_mods_can_change_it() -> void:
	var tools := PackedStringArray(["base:uv_torch", "base:loupe"])
	var base_cost: float = engine.inspection_cost(tools)
	assert_float(base_cost).is_greater(0.0)
	bus.subscribe(
		EventCatalog.INSPECTION_TIME_REQUESTED, func(_p: Dictionary) -> float: return -2.0, "mod"
	)
	assert_float(engine.inspection_cost(tools)).is_equal_approx(base_cost - 2.0, 0.001)


func test_resolution_is_announced_on_the_bus() -> void:
	var seen: Array = []
	bus.subscribe(EventCatalog.VERIFICATION_RESOLVED, func(p: Dictionary) -> void: seen.append(p))
	var encounter: Encounter = engine.create(
		&"base:state_id_northvale", _adult(), PackedStringArray(["id_required"]), false, 4
	)
	engine.resolve(encounter, Encounter.Verdict.APPROVE, _all_tools(), 42)
	assert_int(seen.size()).is_equal(1)
	assert_str(str((seen[0] as Dictionary)["verdict"])).is_equal("approve")
