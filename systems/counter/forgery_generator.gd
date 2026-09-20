class_name ForgeryGenerator
extends RefCounted

## Builds an artifact from a document type, then perturbs it according to weighted
## forgery vectors.
##
## Every vector is a named, data-driven transform, which is what makes the vector set
## combinatorial instead of hand-authored: one "the barcode disagrees with the front"
## definition covers every document that has a barcode, including ones a mod adds later.
##
## The rule this class exists to keep: [b]a forgery the player cannot catch is a bug, not
## difficulty.[/b] Generation is always filtered by the tier the encounter is allowed to
## use, and the caller is expected to have already checked its tools.

const EPOCH_YEAR: int = 2026

var _registry: ContentRegistry
var _rng: SeededRng


func _init(registry: ContentRegistry, rng: SeededRng) -> void:
	_registry = registry
	_rng = rng


## A genuine artifact for [param person], from [param document_type].
func generate_genuine(document_type: ContentDefinition, person: Person, today: int) -> Artifact:
	var artifact := Artifact.new()
	artifact.document_type_id = document_type.id
	artifact.family = document_type.get_text("family")
	artifact.subject_id = person.id
	artifact.typeface = document_type.get_text("typeface")

	for field_spec: Dictionary in document_type.get_value("fields", []):
		var key: String = str(field_spec.get("key", ""))
		artifact.fields[key] = _value_for(key, str(field_spec.get("source", "")), person, today)
	for feature_spec: Dictionary in document_type.get_value("security_features", []):
		artifact.features_present[str(feature_spec.get("id", ""))] = true
	return artifact


## A forged artifact, using vectors that appear at or below [param max_tier].
## Returns a genuine artifact when no vector applies, rather than inventing one.
## The second filter is the fairness rule, and it is not optional: a forgery nobody in
## the building has the instrument to detect is not difficulty, it is a coin flip. Tier
## controls how subtle a catchable forgery is; the toolkit controls which are catchable
## at all.
func generate_forged(
	document_type: ContentDefinition,
	person: Person,
	today: int,
	max_tier: int,
	vector_count: int = 1,
	owned_tools: PackedStringArray = PackedStringArray()
) -> Artifact:
	var artifact: Artifact = generate_genuine(document_type, person, today)
	var candidates: Array = applicable_vectors(document_type, max_tier, owned_tools)
	if candidates.is_empty():
		return artifact
	var chosen: Array = []
	for _index: int in range(maxi(1, vector_count)):
		var vector: ContentDefinition = _rng.pick(SeededRng.FORGERY, candidates)
		if vector != null and not chosen.has(vector):
			chosen.append(vector)
	for vector: ContentDefinition in chosen:
		apply_vector(artifact, vector, person, today)
	return artifact


## Every vector that can be applied to [param document_type] at or below [param max_tier].
## Wildcard targeting plus a field or feature requirement is what makes one definition
## cover many document types.
##
## When [param owned_tools] is given, vectors nothing in that set can detect are excluded.
func applicable_vectors(
	document_type: ContentDefinition,
	max_tier: int = 4,
	owned_tools: PackedStringArray = PackedStringArray()
) -> Array:
	var field_keys: PackedStringArray = []
	for field_spec: Dictionary in document_type.get_value("fields", []):
		field_keys.append(str(field_spec.get("key", "")))
	var feature_ids: PackedStringArray = []
	for feature_spec: Dictionary in document_type.get_value("security_features", []):
		feature_ids.append(str(feature_spec.get("id", "")))

	var out: Array = []
	for vector: ContentDefinition in _registry.by_type(&"forgery_vector"):
		if int(vector.get_number("tier", 99)) > max_tier:
			continue
		var applies: Dictionary = vector.get_value("applies_to", {})
		var targets: Array = applies.get("document_types", [])
		if not targets.has("*") and not targets.has(String(document_type.id)):
			continue
		var needs_field: String = str(applies.get("requires_field", ""))
		if not needs_field.is_empty() and not field_keys.has(needs_field):
			continue
		var needs_feature: String = str(applies.get("requires_feature", ""))
		if not needs_feature.is_empty() and not feature_ids.has(needs_feature):
			continue
		if not owned_tools.is_empty() and not _detectable_with(vector, owned_tools):
			continue
		out.append(vector)
	return out


func _detectable_with(vector: ContentDefinition, owned_tools: PackedStringArray) -> bool:
	for tool_id: String in vector.get_value("detectable_by", []):
		if owned_tools.has(tool_id):
			return true
	return false


## Applies one vector's transform. Unknown ops are ignored and recorded rather than
## crashing: a mod with a typo in a transform must not take the counter down mid-shift.
func apply_vector(
	artifact: Artifact, vector: ContentDefinition, person: Person, today: int
) -> void:
	var transform: Dictionary = vector.get_value("transform", {})
	var op: String = str(transform.get("op", ""))
	var target: String = str(transform.get("target", ""))
	var method: String = str(transform.get("method", ""))

	match op:
		"perturb_field":
			_perturb(artifact, target, method, transform, person, today)
		"set_field":
			_set_field(artifact, target, method, transform, person, today)
		"remove_feature":
			artifact.features_present[target] = false
		"degrade_feature":
			artifact.features_present[target] = false
		"substitute_typeface":
			artifact.typeface = artifact.typeface + "_near_miss"
		"fabricate_field":
			artifact.fields[target] = "unverifiable"
		"apply_process":
			artifact.fields["_process"] = method
			for feature_id: String in artifact.features_present.keys():
				artifact.features_present[feature_id] = false
		"substitute_stock":
			artifact.features_present["layer_core"] = false
		"resize":
			artifact.fields["_dimensions_off_mm"] = _range_value(transform, 0.2, 0.6)
		_:
			artifact.fields["_unknown_transform"] = op

	artifact.applied_vectors.append(vector.id)
	if not target.is_empty():
		artifact.forged_fields.append(target)


func _perturb(
	artifact: Artifact,
	target: String,
	method: String,
	transform: Dictionary,
	person: Person,
	_today: int
) -> void:
	match method:
		"shift_years":
			var years: float = _range_value(transform, 2.0, 6.0)
			# A barcode target writes to the encoded copy, leaving the printed front
			# intact: that disagreement is the whole point of the scanner.
			var key: String = target.replace(".", "_")
			var base_days: int = person.dob_days
			artifact.fields[key] = base_days + int(years * 365.25)
		"different_hand":
			artifact.fields[target] = "signature_mismatch"
		"exceed_print_run":
			artifact.fields[target] = 99999
		_:
			artifact.fields[target] = "altered"


func _set_field(
	artifact: Artifact,
	target: String,
	method: String,
	transform: Dictionary,
	_person: Person,
	today: int
) -> void:
	match method:
		"before":
			var reference: String = str(transform.get("reference", "issued"))
			artifact.fields[target] = int(artifact.fields.get(reference, today)) - 30
		"rotated_set":
			artifact.fields[target] = "rotated_out"
		_:
			artifact.fields[target] = "invalid"


func _range_value(transform: Dictionary, fallback_low: float, fallback_high: float) -> float:
	var bounds: Array = transform.get("range", [fallback_low, fallback_high])
	var low: float = float(bounds[0]) if bounds.size() > 0 else fallback_low
	var high: float = float(bounds[1]) if bounds.size() > 1 else fallback_high
	return _rng.stream(SeededRng.FORGERY).randf_range(low, high)


func _value_for(key: String, source: String, person: Person, today: int) -> Variant:
	match source:
		"person.dob":
			return person.dob_days
		"person.surname", "person.full_name":
			return person.display_name
		"person.given_names":
			return person.display_name.get_slice(" ", 0)
		"person.portrait":
			return person.portrait_id
		"person.height":
			return person.height_cm
		"person.id_number":
			return "ID-%s" % String(person.id)
		"person.signature":
			return "signature_of_%s" % String(person.id)
		"person.claim":
			return "collection_of_%s" % String(person.id)
		"derived.expiry":
			return today + 365 * 3
		"derived.issued":
			return today - 365 * 2
		"derived.holding_end":
			return today + 14
		"world.date":
			return today
		"encoded.all_fields":
			return person.dob_days
		"store.stamp":
			return "house_stamp"
		"card.title":
			return "Meridian Sentinel"
		"card.set":
			return "meridian_core"
		"card.number":
			return 42
		"card.rarity":
			return "mythic"
		"card.copyright":
			return "fictional_publisher_2026"
		"physical.layers":
			return "three_layer_core"
		"physical.mass":
			return 1.75
		_:
			return "%s_value" % key
