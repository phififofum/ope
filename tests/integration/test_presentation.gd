extends GdUnitTestSuite

## The layer between the simulation and the player's eyes. Headless, so it asserts what
## the interface is made of rather than what it looks like -- the visual regression
## harness (tools/visual_regression.py) covers the looking.

var registry: ContentRegistry


func before() -> void:
	registry = ContentRegistry.new()
	ContentLoader.new(registry).load_all("res://content", "res://tests/no_mods")


func _artifact(forged: bool = false) -> Array:
	var bus := EventBus.new()
	var rng := SeededRng.new(31)
	var engine := VerificationEngine.new(registry, bus, rng)
	engine.set_today(20000)
	var person: Person = PersonFactory.new(rng, 20000).create_stranger(30, 40)
	var document: ContentDefinition = registry.get_definition(&"base:state_id_northvale")
	var artifact: Artifact = (
		engine.forgeries.generate_forged(
			document, person, 20000, 1, 1, PackedStringArray(["base:uv_torch"])
		)
		if forged
		else engine.forgeries.generate_genuine(document, person, 20000)
	)
	return [artifact, document]


func _field_texts(renderer: DocumentRenderer) -> PackedStringArray:
	var texts: PackedStringArray = []
	_collect_labels(renderer, texts)
	return texts


func _collect_labels(node: Node, out: PackedStringArray) -> void:
	for child: Node in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		_collect_labels(child, out)


func test_a_document_is_built_from_its_definition_not_from_an_image() -> void:
	var parts: Array = _artifact()
	var renderer := DocumentRenderer.new()
	auto_free(renderer)
	renderer.setup(parts[0], parts[1], registry)
	renderer.set_tools(PackedStringArray(["base:naked_eye"]))

	var texts: PackedStringArray = _field_texts(renderer)
	assert_array(texts).contains(["DOB"])
	assert_array(texts).contains(["EXPIRY"])
	# Dates are stored as days since the epoch and read as dates.
	var has_date: bool = false
	for text: String in texts:
		if text.contains("/20"):
			has_date = true
	assert_bool(has_date).override_failure_message(str(texts)).is_true()


func test_a_field_you_have_no_tool_for_is_absent_rather_than_hidden() -> void:
	var parts: Array = _artifact()
	var renderer := DocumentRenderer.new()
	auto_free(renderer)
	renderer.setup(parts[0], parts[1], registry)

	renderer.set_tools(PackedStringArray(["base:naked_eye"]))
	renderer.show_back = true
	renderer.rebuild()
	assert_array(_field_texts(renderer)).not_contains(["BARCODE"])

	renderer.set_tools(PackedStringArray(["base:naked_eye", "base:barcode_scanner"]))
	assert_array(_field_texts(renderer)).contains(["BARCODE"])


func test_microprint_is_legible_only_when_magnified() -> void:
	var parts: Array = _artifact()
	var renderer := DocumentRenderer.new()
	auto_free(renderer)
	renderer.setup(parts[0], parts[1], registry)
	renderer.set_tools(PackedStringArray(["base:loupe"]))

	renderer.set_zoom(1.0)
	var unmagnified: String = "".join(_field_texts(renderer))
	renderer.set_zoom(3.0)
	var magnified: String = "".join(_field_texts(renderer))

	assert_str(unmagnified).not_contains("PROVINCE OF")
	assert_str(magnified).contains("PROVINCE OF")


func test_a_missing_security_feature_draws_nothing_at_all() -> void:
	# The forgery is not annotated. The player notices an absence, or does not.
	var document: ContentDefinition = registry.get_definition(&"base:state_id_northvale")
	var rng := SeededRng.new(5)
	var person: Person = PersonFactory.new(rng, 20000).create_stranger(30, 40)
	var engine := VerificationEngine.new(registry, EventBus.new(), rng)
	var artifact: Artifact = engine.forgeries.generate_genuine(document, person, 20000)
	engine.forgeries.apply_vector(
		artifact, registry.get_definition(&"base:missing_uv_overlay"), person, 20000
	)

	var renderer := DocumentRenderer.new()
	auto_free(renderer)
	renderer.setup(artifact, document, registry)
	renderer.set_tools(PackedStringArray(["base:uv_torch"]))
	var rendered: String = "".join(_field_texts(renderer))
	assert_str(rendered).not_contains("FAKE")
	assert_str(rendered).not_contains("missing")


func test_accessibility_cues_never_depend_on_colour_alone() -> void:
	var settings := GameSettings.new()
	for severity: String in ["good", "warning", "bad"]:
		(
			assert_str(settings.cue_shape(severity))
			. override_failure_message(
				"%s has no shape, so the cue is carried by colour alone" % severity
			)
			. is_not_empty()
		)
	# Colours differ per colourblind mode, but the shape is what carries the meaning.
	for mode: int in [
		GameSettings.ColourblindMode.NONE,
		GameSettings.ColourblindMode.PROTANOPIA,
		GameSettings.ColourblindMode.DEUTERANOPIA,
		GameSettings.ColourblindMode.TRITANOPIA,
	]:
		settings.colourblind_mode = mode as GameSettings.ColourblindMode
		assert_object(settings.cue_colour("bad")).is_not_equal(settings.cue_colour("good"))


func test_settings_round_trip_through_disk() -> void:
	var settings := GameSettings.new()
	settings.memory_assist = true
	settings.ui_scale = 1.6
	settings.difficulty_preset = "tight"
	assert_bool(settings.save()).is_true()

	var loaded: GameSettings = GameSettings.load_from_disk()
	assert_bool(loaded.memory_assist).is_true()
	assert_float(loaded.ui_scale).is_equal_approx(1.6, 0.001)
	assert_str(loaded.difficulty_preset).is_equal("tight")
	DirAccess.remove_absolute(GameSettings.PATH)


func test_the_world_builds_from_fixture_definitions() -> void:
	var shop := Shop.new(
		registry, EventBus.new(), SeededRng.new(9), Director.Profile.preset("standard"), 1
	)
	var world := ShopWorld.new()
	auto_free(world)
	add_child(world)
	world.build(shop)

	assert_int(world.fixtures.size()).is_greater(10)
	assert_int(world.interactables.size()).is_equal(world.fixtures.size())
	assert_object(world.player).is_not_null()
	# Noise is a field, not a flag: it falls off with distance and shelving attenuates it.
	var near: float = world.noise_at(world.counter_position)
	var far: float = world.noise_at(world.counter_position + Vector3(0.0, 0.0, 9.0))
	assert_float(near).is_greater_equal(far)
	# What the counter cannot see is shrink exposure.
	assert_float(world.counter_sightline()).is_between(0.15, 0.95)


func test_rush_mode_escalates_until_the_queue_wins() -> void:
	var rush := RushMode.new(registry, EventBus.new(), SeededRng.new(77))
	var serve := func(kitchen: Kitchen, now: int) -> void:
		for order: Kitchen.Order in kitchen.pending_orders():
			if order.state == Kitchen.OrderState.WAITING:
				kitchen.start_order(order, now)
				return
			if order.state == Kitchen.OrderState.READY:
				kitchen.serve(order, rush.economy)
				return

	var days: int = 0
	while rush.play_day(serve) and days < 30:
		days += 1
		var offered: Array = rush.offer_upgrades()
		if not offered.is_empty():
			rush.take_upgrade(offered[0])

	assert_int(rush.run.day).is_greater(0)
	assert_int(rush.run.served).is_greater(0)
	# It ends as a wall, not a fail state: it tells you what to rebuild.
	(
		assert_str(rush.run.ended_because)
		. override_failure_message(
			"rush mode never ended; it is supposed to overrun you eventually"
		)
		. is_not_empty()
	)
