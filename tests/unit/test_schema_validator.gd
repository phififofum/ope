extends GdUnitTestSuite

## The validator's messages are the product, not a debug aid: most people who read them
## will be modders with a text editor and no debugger.

const PRODUCT_SCHEMA_PATH: String = "res://content/schemas/product.schema.json"

var validator := SchemaValidator.new()


func _schema(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _valid_product() -> Dictionary:
	return {
		"id": "base:test_item",
		"type": "product",
		"name": "loc:product.test_item",
		"category": "chilled",
		"storage": "chilled",
		"base_cost": 1.0,
		"market_price": 2.0,
		"price_band": [1.5, 3.0],
		"shelf_life_days": 10,
		"licence": "base:general_retail",
		"suppliers": ["base:metro_wholesale"],
	}


func test_a_valid_definition_produces_no_issues() -> void:
	var issues: Array = validator.validate(_valid_product(), _schema(PRODUCT_SCHEMA_PATH), "x.json")
	assert_array(issues).is_empty()


func test_a_missing_required_field_names_the_field() -> void:
	var data: Dictionary = _valid_product()
	data.erase("licence")
	var issues: Array = validator.validate(data, _schema(PRODUCT_SCHEMA_PATH), "x.json")
	assert_int(issues.size()).is_equal(1)
	var issue: ValidationIssue = issues[0]
	assert_str(issue.constraint).is_equal("required")
	assert_str(issue.message).contains("licence")
	assert_str(issue.file_path).is_equal("x.json")


func test_a_typo_in_a_field_name_is_an_error_not_a_silent_no_op() -> void:
	var data: Dictionary = _valid_product()
	data["shelf_footprnt"] = [1, 1]
	var issues: Array = validator.validate(data, _schema(PRODUCT_SCHEMA_PATH), "x.json")
	assert_int(issues.size()).is_equal(1)
	assert_str((issues[0] as ValidationIssue).constraint).is_equal("additionalProperties")


func test_the_json_path_points_at_the_offending_value() -> void:
	var data: Dictionary = _valid_product()
	data["price_band"] = [1.5, "three"]
	var issues: Array = validator.validate(data, _schema(PRODUCT_SCHEMA_PATH), "x.json")
	assert_str((issues[0] as ValidationIssue).json_path).is_equal("$.price_band[1]")


func test_pattern_failures_report_the_pattern() -> void:
	var data: Dictionary = _valid_product()
	data["name"] = "Test Item"  # a literal, not a loc: key
	var issues: Array = validator.validate(data, _schema(PRODUCT_SCHEMA_PATH), "x.json")
	assert_str((issues[0] as ValidationIssue).constraint).is_equal("pattern")


func test_enum_failures_list_what_was_allowed() -> void:
	var data: Dictionary = _valid_product()
	data["storage"] = "lukewarm"
	var issues: Array = validator.validate(data, _schema(PRODUCT_SCHEMA_PATH), "x.json")
	assert_str((issues[0] as ValidationIssue).message).contains("chilled")


func test_numeric_bounds() -> void:
	var schema: Dictionary = {
		"type": "object",
		"properties": {"weight": {"type": "number", "minimum": 0.0, "maximum": 1.0}},
	}
	assert_array(validator.validate({"weight": 0.5}, schema, "x")).is_empty()
	assert_int(validator.validate({"weight": 1.5}, schema, "x").size()).is_equal(1)
	assert_int(validator.validate({"weight": -0.1}, schema, "x").size()).is_equal(1)


func test_integers_accept_whole_floats_because_json_has_one_number_type() -> void:
	var schema: Dictionary = {"type": "object", "properties": {"count": {"type": "integer"}}}
	assert_array(validator.validate({"count": 4.0}, schema, "x")).is_empty()
	assert_int(validator.validate({"count": 4.5}, schema, "x").size()).is_equal(1)


func test_unique_items_and_array_bounds() -> void:
	var schema: Dictionary = {
		"type": "object",
		"properties":
		{"tags": {"type": "array", "uniqueItems": true, "minItems": 1, "maxItems": 2}},
	}
	assert_array(validator.validate({"tags": ["a", "b"]}, schema, "x")).is_empty()
	assert_int(validator.validate({"tags": ["a", "a"]}, schema, "x").size()).is_equal(1)
	assert_int(validator.validate({"tags": []}, schema, "x").size()).is_equal(1)
	assert_int(validator.validate({"tags": ["a", "b", "c"]}, schema, "x").size()).is_equal(1)


func test_an_unsupported_keyword_is_reported_rather_than_ignored() -> void:
	# A constraint the validator silently skips is worse than a missing one: the schema
	# claims a guarantee the game does not enforce.
	var schema: Dictionary = {"type": "object", "allOf": []}
	var issues: Array = validator.validate({}, schema, "x")
	assert_int(issues.size()).is_equal(1)
	assert_str((issues[0] as ValidationIssue).message).contains("allOf")


func test_every_shipped_schema_is_itself_usable() -> void:
	var dir: DirAccess = DirAccess.open("res://content/schemas")
	assert_object(dir).is_not_null()
	for file_name: String in dir.get_files():
		var schema: Dictionary = _schema("res://content/schemas/".path_join(file_name))
		(
			assert_bool(schema.has("type"))
			. override_failure_message("%s has no top-level type" % file_name)
			. is_true()
		)
