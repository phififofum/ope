class_name Artifact
extends RefCounted

## One inspectable thing on the counter: an ID, a trade-in record, a card, a manifest.
##
## It carries three layers, and keeping them apart is what makes the whole loop work:
##
## [b]What it says[/b] — [member fields], the printed values, which may be lies.
## [b]What it is[/b] — [member features_present] and [member applied_vectors], the physical
## truth, which only the right tool reveals.
## [b]Who it is about[/b] — [member subject_id], which may not be the person holding it.

var document_type_id: StringName
var family: String
var fields: Dictionary = {}
var features_present: Dictionary = {}
var typeface: String = ""
var subject_id: StringName

## Ground truth. Host-authoritative: this never leaves the host, and a client only ever
## learns the fields its currently-held tool reveals.
var applied_vectors: Array[StringName] = []
var forged_fields: PackedStringArray = []


func is_forged() -> bool:
	return not applied_vectors.is_empty()


func field(key: String, fallback: Variant = null) -> Variant:
	return fields.get(key, fallback)


func has_feature(feature_id: String) -> bool:
	return bool(features_present.get(feature_id, false))


## Which fields a player holding [param owned_tools] can actually read. A field with a
## [code]revealed_by[/code] tool is invisible without it — that is the tool tree's whole
## job.
func readable_fields(
	document_type: ContentDefinition, owned_tools: PackedStringArray
) -> PackedStringArray:
	var readable: PackedStringArray = []
	for field_spec: Dictionary in document_type.get_value("fields", []):
		var required_tool: String = str(field_spec.get("revealed_by", ""))
		if required_tool.is_empty() or owned_tools.has(required_tool):
			readable.append(str(field_spec.get("key", "")))
	return readable


func checkable_features(
	document_type: ContentDefinition, owned_tools: PackedStringArray
) -> PackedStringArray:
	var checkable: PackedStringArray = []
	for feature_spec: Dictionary in document_type.get_value("security_features", []):
		if owned_tools.has(str(feature_spec.get("revealed_by", ""))):
			checkable.append(str(feature_spec.get("id", "")))
	return checkable
