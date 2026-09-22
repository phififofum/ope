extends GdUnitTestSuite

## Loads the real shipped content through the real loader. If this fails, the game does
## not start — which is exactly why it runs on every commit.

var registry: ContentRegistry
var report: ContentLoader.LoadReport


func before() -> void:
	registry = ContentRegistry.new()
	var loader := ContentLoader.new(registry)
	# No mods: this is the base game on its own.
	report = loader.load_all("res://content", "res://tests/no_such_directory")


func test_base_content_loads_without_a_single_issue() -> void:
	assert_str(report.summary()).contains("loaded")
	assert_array(report.errors()).override_failure_message(report.summary()).is_empty()
	assert_int(report.rejected_count).is_equal(0)


func test_every_shipped_type_is_present_and_queryable() -> void:
	for type_name: String in [
		"product", "supplier", "licence", "tool", "document_type", "forgery_vector", "recipe", "cat"
	]:
		(
			assert_int(registry.count_of(StringName(type_name)))
			. override_failure_message("no definitions of type %s" % type_name)
			. is_greater(0)
		)


func test_query_by_tag_finds_content_no_system_named() -> void:
	var chilled: Array = registry.by_tags(&"product", PackedStringArray(["chilled"]))
	assert_int(chilled.size()).is_greater(0)
	for definition: ContentDefinition in chilled:
		assert_str(definition.get_text("storage")).is_equal("chilled")


func test_ids_are_namespaced_to_their_source() -> void:
	for definition: ContentDefinition in registry.by_type(&"product"):
		assert_str(definition.id_namespace()).is_equal("base")
		assert_str(definition.source_id).is_equal("base")


func test_every_referenced_id_resolves() -> void:
	# A dangling reference is the failure that looks fine at load and explodes on the
	# first customer, so it is checked here rather than discovered in play.
	for product: ContentDefinition in registry.by_type(&"product"):
		(
			assert_bool(registry.has(StringName(product.get_text("licence"))))
			. override_failure_message("%s references a licence that does not exist" % product.id)
			. is_true()
		)
		for supplier_id: String in product.get_value("suppliers", []):
			(
				assert_bool(registry.has(StringName(supplier_id)))
				. override_failure_message(
					"%s references supplier %s, which does not exist" % [product.id, supplier_id]
				)
				. is_true()
			)
	for recipe: ContentDefinition in registry.by_type(&"recipe"):
		for ingredient: Dictionary in recipe.get_value("ingredients", []):
			assert_bool(registry.has(StringName(str(ingredient.get("product", ""))))).is_true()


func test_every_forgery_vector_is_catchable_with_a_tool_available_at_its_tier() -> void:
	# The fairness rule, enforced in-engine as well as in CI: the game never demands a
	# coin flip.
	for vector: ContentDefinition in registry.by_type(&"forgery_vector"):
		var tier: int = int(vector.get_number("tier", 99))
		var reachable: bool = false
		for tool_id: String in vector.get_value("detectable_by", []):
			var tool: ContentDefinition = registry.get_definition(StringName(tool_id))
			if tool != null and int(tool.get_number("tier", 99)) <= tier:
				reachable = true
				break
		(
			assert_bool(reachable)
			. override_failure_message(
				"%s appears at tier %d with no tool available by then" % [vector.id, tier]
			)
			. is_true()
		)


func test_no_tool_returns_a_verdict() -> void:
	# Tools reveal; players judge. A tool that answers the question ends the game's
	# central verb.
	for tool: ContentDefinition in registry.by_type(&"tool"):
		(
			assert_bool(bool(tool.get_value("returns_verdict", false)))
			. override_failure_message("%s returns a verdict" % tool.id)
			. is_false()
		)


func test_a_malformed_definition_names_the_file_the_path_and_the_constraint() -> void:
	var directory: String = "user://broken_content_fixture"
	_write_source(
		directory,
		{"id": "broken", "name": "Broken", "version": "1.0.0", "game_api": "*"},
		{
			"product/bad_item.json":
			{
				"id": "broken:bad_item",
				"type": "product",
				"name": "Not A Loc Key",
				"category": "chilled",
				"storage": "chilled",
				"base_cost": 1.0,
				"market_price": 2.0,
				"price_band": [1.0, 3.0],
				"shelf_life_days": 5,
				"licence": "base:general_retail",
				"suppliers": ["base:metro_wholesale"],
			}
		}
	)
	# Schemas come from the base game; this source only supplies the broken definition.
	var local_registry := ContentRegistry.new()
	var loader := ContentLoader.new(local_registry)
	var local_report: ContentLoader.LoadReport = loader.load_all(
		"res://content", directory.get_base_dir()
	)

	var found: ValidationIssue = null
	for issue: ValidationIssue in local_report.errors():
		if issue.file_path.contains("bad_item"):
			found = issue
			break
	assert_object(found).override_failure_message(local_report.summary()).is_not_null()
	assert_str(found.json_path).is_equal("$.name")
	assert_str(found.constraint).is_equal("pattern")
	assert_bool(local_registry.has(&"broken:bad_item")).is_false()
	_remove_tree(directory)


func _write_source(directory: String, manifest: Dictionary, definitions: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest_file: FileAccess = FileAccess.open(
		directory.path_join("manifest.json"), FileAccess.WRITE
	)
	manifest_file.store_string(JSON.stringify(manifest))
	manifest_file.close()
	for relative_path: String in definitions.keys():
		var full_path: String = directory.path_join("definitions").path_join(relative_path)
		DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
		var file: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(definitions[relative_path]))
		file.close()


func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for sub_name: String in dir.get_directories():
		_remove_tree(path.path_join(sub_name))
	DirAccess.remove_absolute(path)


func test_every_kind_of_equipment_does_something_when_bought() -> void:
	# An upgrade whose category the shop does not recognise is money taken for nothing.
	# Forty-five of these ship; this is the check that they all land somewhere.
	var categories: Dictionary = {}
	for upgrade: ContentDefinition in registry.by_type(&"upgrade"):
		categories[upgrade.get_text("category")] = true
	for category: String in categories.keys():
		(
			assert_bool(Shop.UPGRADE_HELPS.has(category))
			. override_failure_message(
				"upgrades of category '%s' ship in content but shorten no task" % category
			)
			. is_true()
		)
