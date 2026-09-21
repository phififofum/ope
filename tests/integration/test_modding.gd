extends GdUnitTestSuite

## The Phase 1 gate: a mod adds a product, overrides a base product, and vetoes a sale —
## with no engine code changed. Plus every way mod loading is allowed to fail.

const FIXTURE_MODS: String = "res://tests/mods"

var registry: ContentRegistry
var bus: EventBus
var runtime: ModRuntime
var report: ContentLoader.LoadReport


func before_test() -> void:
	registry = ContentRegistry.new()
	bus = EventBus.new()
	runtime = ModRuntime.new()
	var loader := ContentLoader.new(registry)
	report = loader.load_all("res://content", FIXTURE_MODS)
	var resolution: ModLoader.Resolution = ModLoader.resolve(ModLoader.discover(FIXTURE_MODS))
	runtime.activate_all(resolution.order, registry, bus)


func after_test() -> void:
	bus.unsubscribe_owner("veto_mod")


# --- The gate ---------------------------------------------------------------------


func test_a_mod_adds_a_product() -> void:
	(
		assert_bool(registry.has(&"veto_mod:contraband_energy_drink"))
		. override_failure_message(report.summary())
		. is_true()
	)
	var added: ContentDefinition = registry.get_definition(&"veto_mod:contraband_energy_drink")
	assert_str(added.source_id).is_equal("veto_mod")
	# It plugs into systems that never heard of it: tag queries find it.
	var chilled: Array = registry.by_tags(&"product", PackedStringArray(["chilled"]))
	assert_array(chilled).contains([added])


func test_a_mod_overrides_a_base_product_and_the_override_is_recorded() -> void:
	var overridden: ContentDefinition = registry.get_definition(&"base:cold_brew_16oz")
	assert_str(overridden.source_id).is_equal("veto_mod")
	assert_float(overridden.get_number("market_price")).is_equal_approx(9.99, 0.001)

	var recorded: bool = false
	for entry: Dictionary in registry.overrides():
		if entry["id"] == "base:cold_brew_16oz":
			assert_str(str(entry["overridden_source"])).is_equal("base")
			assert_str(str(entry["winning_source"])).is_equal("veto_mod")
			recorded = true
	assert_bool(recorded).is_true()


func test_a_mod_script_vetoes_a_sale() -> void:
	var refused: EventOutcome = bus.attempt(
		EventCatalog.SALE_ATTEMPTED, {"age_restricted": true, "id_verified": false}
	)
	assert_bool(refused.allowed).is_false()
	assert_str(refused.vetoed_by).is_equal("veto_mod")
	assert_str(refused.reason).contains("ID")

	var allowed: EventOutcome = bus.attempt(
		EventCatalog.SALE_ATTEMPTED, {"age_restricted": true, "id_verified": true}
	)
	assert_bool(allowed.allowed).is_true()


func test_a_mod_script_contributes_to_a_query() -> void:
	assert_float(bus.query(EventCatalog.PRICE_REQUESTED, {}, 10.0)).is_equal_approx(11.0, 0.001)


func test_a_mod_script_can_define_content_at_runtime() -> void:
	assert_bool(registry.has(&"veto_mod:runtime_defined_tool")).is_true()


func test_deactivating_a_mod_removes_its_content_and_its_subscriptions() -> void:
	runtime.deactivate("veto_mod", registry, bus, "test")
	assert_bool(registry.has(&"veto_mod:runtime_defined_tool")).is_false()
	(
		assert_bool(bus.attempt(EventCatalog.SALE_ATTEMPTED, {"age_restricted": true}).allowed)
		. is_true()
	)


# --- Load order and dependency resolution -----------------------------------------


func test_a_dependency_loads_before_its_dependent() -> void:
	var resolution: ModLoader.Resolution = ModLoader.resolve(ModLoader.discover(FIXTURE_MODS))
	var ids: PackedStringArray = resolution.ids()
	assert_array(ids).contains(["veto_mod", "dependent_mod"])
	assert_int(ids.find("veto_mod")).is_less(ids.find("dependent_mod"))


func test_the_resolved_order_is_the_same_every_run() -> void:
	# Two mods with equal load_order must not swap places between runs, or the host and
	# the client disagree about which override won.
	var first: PackedStringArray = ModLoader.resolve(ModLoader.discover(FIXTURE_MODS)).ids()
	for _attempt: int in range(5):
		assert_array(ModLoader.resolve(ModLoader.discover(FIXTURE_MODS)).ids()).is_equal(first)


func test_a_three_mod_chain_resolves() -> void:
	var manifests: Array[ModManifest] = [
		_manifest("c", {"b": ">=1.0.0"}),
		_manifest("a", {}),
		_manifest("b", {"a": ">=1.0.0"}),
	]
	var resolution: ModLoader.Resolution = ModLoader.resolve(manifests)
	assert_array(resolution.ids()).is_equal(PackedStringArray(["a", "b", "c"]))
	assert_bool(resolution.is_clean()).is_true()


func test_a_missing_dependency_disables_only_the_dependent() -> void:
	var manifests: Array[ModManifest] = [_manifest("a", {}), _manifest("b", {"absent": ">=1.0.0"})]
	var resolution: ModLoader.Resolution = ModLoader.resolve(manifests)
	assert_array(resolution.ids()).is_equal(PackedStringArray(["a"]))
	assert_str(str(resolution.disabled["b"])).contains("absent")


func test_a_dependency_failure_cascades() -> void:
	# c needs b, b needs something absent. Both are disabled; a still loads.
	var manifests: Array[ModManifest] = [
		_manifest("a", {}),
		_manifest("b", {"absent": ">=1.0.0"}),
		_manifest("c", {"b": ">=1.0.0"}),
	]
	var resolution: ModLoader.Resolution = ModLoader.resolve(manifests)
	assert_array(resolution.ids()).is_equal(PackedStringArray(["a"]))
	assert_int(resolution.disabled.size()).is_equal(2)


func test_a_dependency_cycle_is_reported_with_the_cycle_in_it() -> void:
	var manifests: Array[ModManifest] = [
		_manifest("a", {"b": ">=1.0.0"}),
		_manifest("b", {"a": ">=1.0.0"}),
	]
	var resolution: ModLoader.Resolution = ModLoader.resolve(manifests)
	assert_array(resolution.order).is_empty()
	assert_str(", ".join(resolution.errors)).contains("cycle")
	assert_int(resolution.disabled.size()).is_equal(2)


func test_a_version_mismatch_says_what_was_wanted_and_what_was_found() -> void:
	var dependency: ModManifest = _manifest("dep", {})
	dependency.version = "0.9.0"
	var resolution: ModLoader.Resolution = ModLoader.resolve(
		[dependency, _manifest("needs_newer", {"dep": ">=1.0.0"})]
	)
	assert_str(str(resolution.disabled["needs_newer"])).contains("0.9.0")


func test_a_mod_outside_the_api_range_is_disabled_not_loaded_to_crash() -> void:
	var manifest: ModManifest = _manifest("ancient", {})
	manifest.game_api = ">=99.0.0"
	var resolution: ModLoader.Resolution = ModLoader.resolve([manifest])
	assert_array(resolution.order).is_empty()
	assert_str(str(resolution.disabled["ancient"])).contains("99.0.0")


func test_a_manifest_that_is_not_json_disables_only_that_mod() -> void:
	var directory: String = "user://broken_manifest_mod"
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string("{ not json at all")
	file.close()
	var manifest: ModManifest = ModLoader.read_manifest(directory)
	assert_bool(manifest.is_valid()).is_false()
	var resolution: ModLoader.Resolution = ModLoader.resolve([manifest, _manifest("fine", {})])
	assert_array(resolution.ids()).is_equal(PackedStringArray(["fine"]))
	DirAccess.remove_absolute(directory.path_join("manifest.json"))
	DirAccess.remove_absolute(directory)


func test_cosmetic_mods_do_not_block_a_multiplayer_join() -> void:
	var cosmetic: ModManifest = ModLoader.read_manifest(FIXTURE_MODS.path_join("cosmetic_mod"))
	var gameplay: ModManifest = ModLoader.read_manifest(FIXTURE_MODS.path_join("veto_mod"))
	assert_bool(cosmetic.blocks_multiplayer_join()).is_false()
	assert_bool(gameplay.blocks_multiplayer_join()).is_true()


func _manifest(id: String, dependencies: Dictionary) -> ModManifest:
	return (
		ModManifest
		. from_dictionary(
			{
				"id": id,
				"name": id,
				"version": "1.0.0",
				"game_api": "*",
				"dependencies": dependencies,
				"load_order": 100,
			},
			"user://none/%s" % id
		)
	)
