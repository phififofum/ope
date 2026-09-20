class_name RuleEngine
extends RefCounted

## Evaluates the checklist.
##
## Rules are data, so the binder the player consults, the checks the game enforces and the
## list a modder extends are all the same objects — which is why the binder can never be
## out of date, and why mod-added rules appear in it with no extra work.
##
## Three outcomes per rule, and the third one is the interesting one:
##   PASS            — checked, and fine.
##   FAIL            — checked, and wrong.
##   UNCHECKED       — you own the tool and did not reach for it. Not a pass: this is
##                     scrutiny you chose not to spend, and it is where misses come from.
##   NOT_APPLICABLE  — you do not own the tool at all. Not your failing: the director
##                     only sends forgeries the current toolkit can catch, so a rule you
##                     have no instrument for is not a gap you can be blamed for.

enum Status { PASS, FAIL, UNCHECKED, NOT_APPLICABLE }


class Finding:
	extends RefCounted
	var rule_id: StringName
	var status: Status
	var severity: String
	var message: String
	var requires_tool: String

	func failed() -> bool:
		return status == Status.FAIL

	func blocking() -> bool:
		return failed() and severity == "blocking"

	func item_scoped() -> bool:
		return failed() and severity == "item_scoped"


var _registry: ContentRegistry


func _init(registry: ContentRegistry) -> void:
	_registry = registry


## Every rule that applies to [param artifact] given [param transaction_tags].
func applicable_rules(artifact: Artifact, transaction_tags: PackedStringArray) -> Array:
	var out: Array = []
	for rule: ContentDefinition in _registry.by_type(&"rule"):
		var applies: Dictionary = rule.get_value("applies_to", {})
		var families: Array = applies.get("document_families", [])
		if not families.is_empty() and not families.has(artifact.family):
			continue
		var types: Array = applies.get("document_types", [])
		if not types.is_empty() and not types.has(String(artifact.document_type_id)):
			continue
		var required_tags: Array = applies.get("transaction_tags", [])
		var matched: bool = required_tags.is_empty()
		for tag: String in required_tags:
			if transaction_tags.has(tag):
				matched = true
				break
		if not matched:
			continue
		out.append(rule)
	return out


## [param used_tools] is what the player actually reached for. [param owned_tools] is
## everything they could have reached for; when omitted it is the same set.
func evaluate(
	artifact: Artifact,
	person: Person,
	transaction_tags: PackedStringArray,
	used_tools: PackedStringArray,
	today: int,
	owned_tools: PackedStringArray = PackedStringArray()
) -> Array:
	var owned: PackedStringArray = owned_tools if not owned_tools.is_empty() else used_tools
	var findings: Array = []
	for rule: ContentDefinition in applicable_rules(artifact, transaction_tags):
		findings.append(_evaluate_one(rule, artifact, person, used_tools, owned, today))
	return findings


func _evaluate_one(
	rule: ContentDefinition,
	artifact: Artifact,
	person: Person,
	used_tools: PackedStringArray,
	owned_tools: PackedStringArray,
	today: int
) -> Finding:
	var finding := Finding.new()
	finding.rule_id = rule.id
	finding.severity = rule.get_text("severity", "blocking")
	finding.requires_tool = rule.get_text("requires_tool", "")
	finding.message = rule.get_text("name")

	if not finding.requires_tool.is_empty():
		if not owned_tools.has(finding.requires_tool):
			finding.status = Status.NOT_APPLICABLE
			return finding
		if not used_tools.has(finding.requires_tool):
			finding.status = Status.UNCHECKED
			return finding

	var check: Dictionary = rule.get_value("check", {})
	finding.status = Status.PASS if _check(check, artifact, person, today) else Status.FAIL
	return finding


func _check(check: Dictionary, artifact: Artifact, person: Person, today: int) -> bool:
	var op: String = str(check.get("op", ""))
	var field_key: String = str(check.get("field", ""))
	match op:
		"age_at_least":
			var dob: int = int(artifact.field(field_key, person.dob_days))
			var years: float = float(today - dob) / 365.25
			return years >= float(check.get("value", 18))
		"not_expired":
			return int(artifact.field(field_key, today + 1)) >= today
		"fields_match":
			var keys: Array = check.get("fields", [])
			if keys.size() < 2:
				return true
			var first: Variant = _resolve(artifact, str(keys[0]))
			for index: int in range(1, keys.size()):
				if not _same(first, _resolve(artifact, str(keys[index]))):
					return false
			return true
		"feature_present":
			return artifact.has_feature(str(check.get("feature", "")))
		"matches_person":
			return str(artifact.field(field_key, "")) == person.portrait_id
		"field_equals":
			var expected: Variant = check.get("value")
			if expected == "__from_person__":
				return str(artifact.field(field_key, "")) == "ID-%s" % String(person.id)
			if expected == "__legal_set__":
				return str(artifact.field(field_key, "")) != "rotated_out"
			return _same(artifact.field(field_key), expected)
		"within_threshold":
			# Physical tolerances: a weight or a trim outside its band. Absent data reads
			# as in-tolerance, because the check is "is it wrong", not "did we measure".
			var deviation: float = absf(float(artifact.field("_dimensions_off_mm", 0.0)))
			var weight_field: Variant = artifact.field(field_key)
			if weight_field is float or weight_field is int:
				deviation = maxf(deviation, absf(float(weight_field) - 1.75))
			return deviation <= float(check.get("threshold", 1.0))
		"holding_period":
			return int(artifact.field(field_key, today - 1)) <= today
		"typeface_matches":
			return not artifact.typeface.ends_with("_near_miss")
		"physically_intact":
			return (
				not artifact.fields.has("_process")
				and not artifact.fields.has("_unknown_transform")
			)
	return true


func _resolve(artifact: Artifact, key: String) -> Variant:
	# "barcode.dob" is the encoded copy of a printed field, stored flattened so that a
	# mismatch between the two is expressible.
	var flattened: String = key.replace(".", "_")
	if artifact.fields.has(flattened):
		return artifact.fields[flattened]
	if artifact.fields.has(key):
		return artifact.fields[key]
	if key.begins_with("barcode."):
		return artifact.fields.get("barcode", null)
	return null


func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b
