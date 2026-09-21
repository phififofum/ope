class_name ContentDefinition
extends RefCounted

## One definition, as installed in the registry: its id, its type, its tags, the source
## that provided it, and the validated data itself.
##
## Systems read definitions through this rather than holding the raw dictionary, so that
## "which mod did this come from" is answerable at runtime — which is what makes the mod
## error screen and the multiplayer manifest comparison possible.

var id: StringName
var type: StringName
var source_id: String
var data: Dictionary
var tags: PackedStringArray


static func from_data(definition_data: Dictionary, source_id: String) -> ContentDefinition:
	var definition := ContentDefinition.new()
	definition.id = StringName(str(definition_data.get("id", "")))
	definition.type = StringName(str(definition_data.get("type", "")))
	definition.source_id = source_id
	definition.data = definition_data
	for tag: String in definition_data.get("tags", []):
		definition.tags.append(tag)
	return definition


func id_namespace() -> String:
	return String(id).get_slice(":", 0)


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func has_all_tags(required: PackedStringArray) -> bool:
	for tag: String in required:
		if not tags.has(tag):
			return false
	return true


func get_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)


func get_number(key: String, fallback: float = 0.0) -> float:
	var value: Variant = data.get(key, fallback)
	if value is float or value is int:
		return float(value)
	return fallback


func get_text(key: String, fallback: String = "") -> String:
	var value: Variant = data.get(key, fallback)
	return str(value) if value != null else fallback
