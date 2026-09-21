class_name SchemaValidator
extends RefCounted

## Validates a definition against its JSON Schema, in-engine, at load.
##
## The same schemas are used by tools/validate_content.py, by editors that read
## content/schemas/ for autocomplete, and by this class at boot. One source of truth: a
## mod that validates in the CLI loads in the game, and one that does not fails in both
## places with the same message.
##
## This implements the subset of JSON Schema draft 2020-12 the project's schemas use.
## Anything unsupported is reported rather than ignored, because a silently skipped
## constraint is worse than a missing one.

const SUPPORTED_KEYWORDS: PackedStringArray = [
	"$schema",
	"$id",
	"title",
	"description",
	"type",
	"const",
	"enum",
	"required",
	"properties",
	"additionalProperties",
	"propertyNames",
	"items",
	"minItems",
	"maxItems",
	"uniqueItems",
	"pattern",
	"minimum",
	"maximum",
	"exclusiveMinimum",
	"exclusiveMaximum",
	"minLength",
	"maxLength",
]

var _file_path: String = "<unknown>"
var _issues: Array[ValidationIssue] = []


## Validates [param data] against [param schema]. [param file_path] is reported in every
## issue, because "expected string" with no file is not an error message.
func validate(data: Variant, schema: Dictionary, file_path: String) -> Array[ValidationIssue]:
	_file_path = file_path
	_issues = []
	_validate_value(data, schema, "$")
	return _issues


func _add(json_path: String, constraint: String, message: String) -> void:
	_issues.append(ValidationIssue.error(_file_path, json_path, constraint, message))


func _validate_value(value: Variant, schema: Dictionary, path: String) -> void:
	for keyword: String in schema.keys():
		if not SUPPORTED_KEYWORDS.has(keyword):
			_add(path, keyword, "schema uses unsupported keyword '%s'" % keyword)

	if schema.has("const") and not _values_equal(value, schema["const"]):
		_add(path, "const", "must be %s" % [schema["const"]])
		return

	if schema.has("enum"):
		var allowed: Array = schema["enum"]
		var matched: bool = false
		for candidate: Variant in allowed:
			if _values_equal(value, candidate):
				matched = true
				break
		if not matched:
			_add(path, "enum", "must be one of %s, got %s" % [allowed, value])
			return

	if schema.has("type") and not _matches_type(value, schema["type"]):
		_add(path, "type", "expected %s, got %s" % [schema["type"], _type_name(value)])
		return

	if value is Dictionary:
		_validate_object(value, schema, path)
	elif value is Array:
		_validate_array(value, schema, path)
	elif value is String:
		_validate_string(value, schema, path)
	elif value is float or value is int:
		_validate_number(float(value), schema, path)


func _validate_object(value: Dictionary, schema: Dictionary, path: String) -> void:
	var properties: Dictionary = schema.get("properties", {})

	for required_key: String in schema.get("required", []):
		if not value.has(required_key):
			_add(path, "required", "missing required property '%s'" % required_key)

	var additional: Variant = schema.get("additionalProperties", true)
	var property_names: Dictionary = schema.get("propertyNames", {})

	for key: String in value.keys():
		var child_path: String = "%s.%s" % [path, key]
		if not property_names.is_empty():
			_validate_value(key, property_names, child_path)
		if properties.has(key):
			_validate_value(value[key], properties[key], child_path)
		elif additional is Dictionary:
			_validate_value(value[key], additional, child_path)
		elif additional is bool and not additional:
			# A typo'd field must be an error. Silently ignoring it means a modder
			# spends an hour wondering why `shelf_footprnt` does nothing.
			_add(child_path, "additionalProperties", "unknown property '%s'" % key)


func _validate_array(value: Array, schema: Dictionary, path: String) -> void:
	if schema.has("minItems") and value.size() < int(schema["minItems"]):
		_add(
			path,
			"minItems",
			"needs at least %d item(s), has %d" % [int(schema["minItems"]), value.size()]
		)
	if schema.has("maxItems") and value.size() > int(schema["maxItems"]):
		_add(
			path,
			"maxItems",
			"allows at most %d item(s), has %d" % [int(schema["maxItems"]), value.size()]
		)
	if schema.get("uniqueItems", false):
		var seen: Array = []
		for entry: Variant in value:
			for previous: Variant in seen:
				if _values_equal(entry, previous):
					_add(path, "uniqueItems", "duplicate entry %s" % [entry])
					break
			seen.append(entry)
	if schema.has("items"):
		var item_schema: Dictionary = schema["items"]
		for index: int in range(value.size()):
			_validate_value(value[index], item_schema, "%s[%d]" % [path, index])


func _validate_string(value: String, schema: Dictionary, path: String) -> void:
	if schema.has("pattern"):
		var regex := RegEx.new()
		if regex.compile(schema["pattern"]) != OK:
			_add(path, "pattern", "schema has an invalid regex: %s" % schema["pattern"])
		elif regex.search(value) == null:
			_add(path, "pattern", "'%s' does not match %s" % [value, schema["pattern"]])
	if schema.has("minLength") and value.length() < int(schema["minLength"]):
		_add(path, "minLength", "shorter than %d characters" % int(schema["minLength"]))
	if schema.has("maxLength") and value.length() > int(schema["maxLength"]):
		_add(path, "maxLength", "longer than %d characters" % int(schema["maxLength"]))


func _validate_number(value: float, schema: Dictionary, path: String) -> void:
	if schema.has("minimum") and value < float(schema["minimum"]):
		_add(path, "minimum", "%s is below the minimum %s" % [value, schema["minimum"]])
	if schema.has("maximum") and value > float(schema["maximum"]):
		_add(path, "maximum", "%s is above the maximum %s" % [value, schema["maximum"]])
	if schema.has("exclusiveMinimum") and value <= float(schema["exclusiveMinimum"]):
		_add(
			path,
			"exclusiveMinimum",
			"%s must be greater than %s" % [value, schema["exclusiveMinimum"]]
		)
	if schema.has("exclusiveMaximum") and value >= float(schema["exclusiveMaximum"]):
		_add(
			path,
			"exclusiveMaximum",
			"%s must be less than %s" % [value, schema["exclusiveMaximum"]]
		)


func _matches_type(value: Variant, type_spec: Variant) -> bool:
	if type_spec is Array:
		for candidate: String in type_spec:
			if _matches_type(value, candidate):
				return true
		return false
	match str(type_spec):
		"object":
			return value is Dictionary
		"array":
			return value is Array
		"string":
			return value is String or value is StringName
		"boolean":
			return value is bool
		"integer":
			# JSON has one number type and Godot's parser returns floats, so an integer
			# is a number with nothing after the point.
			if value is int:
				return true
			return value is float and is_equal_approx(value, roundf(value))
		"number":
			return (value is float or value is int) and not value is bool
		"null":
			return value == null
	return true


func _type_name(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Dictionary:
		return "object"
	if value is Array:
		return "array"
	if value is String or value is StringName:
		return "string"
	if value is bool:
		return "boolean"
	if value is int:
		return "integer"
	if value is float:
		return "number"
	return "unknown"


func _values_equal(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b
