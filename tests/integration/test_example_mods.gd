extends GdUnitTestSuite

## The three example mods, one per tier, kept passing here so the documentation cannot
## quietly stop being true. If a mod of each tier does not load, the SDK is a claim.

const EXAMPLES: String = "res://examples/mods"

var registry: ContentRegistry
var bus: EventBus
var runtime: ModRuntime
var report: ContentLoader.LoadReport


func before_test() -> void:
	registry = ContentRegistry.new()
	bus = EventBus.new()
	runtime = ModRuntime.new()
	report = ContentLoader.new(registry).load_all("res://content", EXAMPLES)
	var resolution: ModLoader.Resolution = ModLoader.resolve(ModLoader.discover(EXAMPLES))
	runtime.activate_all(resolution.order, registry, bus)


func after_test() -> void:
	for mod_id: String in ["late_shift_menu", "corner_booth", "house_rules"]:
		bus.unsubscribe_owner(mod_id)


func test_all_three_load_cleanly() -> void:
	assert_array(report.errors()).override_failure_message(report.summary()).is_empty()
	for mod_id: String in ["late_shift_menu", "corner_booth", "house_rules"]:
		assert_array(report.sources).contains([mod_id])
	assert_bool(report.disabled_sources.is_empty()).is_true()


func test_tier_one_needs_nothing_but_a_text_editor() -> void:
	# Data only: products and a recipe, referencing base content by id.
	assert_bool(registry.has(&"late_shift_menu:instant_ramen")).is_true()
	var recipe: ContentDefinition = registry.get_definition(&"late_shift_menu:three_am_ramen")
	assert_object(recipe).is_not_null()
	assert_str(recipe.get_text("unlocked_by")).is_equal("base:food_service")
	# And it plugs into systems that never heard of it.
	var impulse: Array = registry.by_tags(&"product", PackedStringArray(["impulse"]))
	var found: bool = false
	for definition: ContentDefinition in impulse:
		if definition.source_id == "late_shift_menu":
			found = true
	assert_bool(found).is_true()


func test_tier_two_ships_a_fixture_and_its_licence_record() -> void:
	var fixture: ContentDefinition = registry.get_definition(&"corner_booth:corner_booth")
	assert_object(fixture).is_not_null()
	assert_float(fixture.get_number("noise")).is_less(0.0)  # a booth attenuates noise
	var manifest: ModManifest = ModLoader.read_manifest(EXAMPLES.path_join("corner_booth"))
	# Cosmetic-only, so a mismatch warns rather than blocking the join.
	assert_bool(manifest.blocks_multiplayer_join()).is_false()
	(
		assert_bool(
			FileAccess.file_exists(
				EXAMPLES.path_join("corner_booth/assets/booth_decal.svg.license.json")
			)
		)
		. is_true()
	)


func test_tier_three_adds_a_mechanic_with_no_engine_code() -> void:
	# A house ceiling on trade-ins: a rule the shop sets for itself, enforced through the
	# same bus a base system would use.
	var first: EventOutcome = bus.attempt(EventCatalog.TRADE_IN_ATTEMPTED, {"value": -200.0})
	assert_bool(first.allowed).is_true()
	var second: EventOutcome = bus.attempt(EventCatalog.TRADE_IN_ATTEMPTED, {"value": -200.0})
	assert_bool(second.allowed).is_false()
	assert_str(second.vetoed_by).is_equal("house_rules")
	assert_str(second.reason).contains("ceiling")

	# And a blanket carding policy, which is a veto on an entirely different event.
	var sale: EventOutcome = bus.attempt(
		EventCatalog.SALE_ATTEMPTED, {"age_restricted": true, "id_verified": false}
	)
	assert_bool(sale.allowed).is_false()

	# Query contributions aggregate deterministically.
	assert_float(bus.query(EventCatalog.PATIENCE_MODIFIER_REQUESTED, {}, 1.0)).is_equal_approx(
		1.08, 0.001
	)


func test_a_mod_added_rule_is_enforced_like_any_other() -> void:
	# The binder is generated from the same objects that enforce the rules, so a
	# mod-added rule appears in it with no extra work from the modder.
	var rule: ContentDefinition = registry.get_definition(
		&"house_rules:no_trade_ins_after_midnight"
	)
	assert_object(rule).is_not_null()
	var engine := RuleEngine.new(registry)
	var artifact := Artifact.new()
	artifact.family = "commercial"
	artifact.document_type_id = &"base:trade_in_record"
	artifact.fields = {"declared_provenance": "unverifiable"}
	var applicable: Array = engine.applicable_rules(artifact, PackedStringArray(["trade_in"]))
	var names: PackedStringArray = []
	for applied: ContentDefinition in applicable:
		names.append(String(applied.id))
	assert_array(names).contains(["house_rules:no_trade_ins_after_midnight"])
