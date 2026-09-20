class_name ContentLoader
extends RefCounted

## Walks content sources in load order, validates every definition against its type's
## schema, and installs the survivors into the registry.
##
## The base game goes through this path exactly like a mod does. There is no second
## loader and no fast path: [code]content/[/code] is simply the source with load order
## zero.

const BASE_CONTENT_PATH: String = "res://content"
const MODS_PATH: String = "res://mods"


class LoadReport:
	extends RefCounted
	var issues: Array[ValidationIssue] = []
	var loaded_count: int = 0
	var rejected_count: int = 0
	var sources: PackedStringArray = []
	var disabled_sources: Dictionary = {}

	func errors() -> Array[ValidationIssue]:
		var out: Array[ValidationIssue] = []
		for issue: ValidationIssue in issues:
			if issue.is_error():
				out.append(issue)
		return out

	func is_clean() -> bool:
		return errors().is_empty() and disabled_sources.is_empty()

	func summary() -> String:
		var lines: PackedStringArray = []
		lines.append(
			(
				"loaded %d definition(s) from %d source(s); %d rejected"
				% [loaded_count, sources.size(), rejected_count]
			)
		)
		for issue: ValidationIssue in issues:
			lines.append("  " + issue.to_text())
		for source_id: String in disabled_sources.keys():
			lines.append("  DISABLED  %s: %s" % [source_id, disabled_sources[source_id]])
		return "\n".join(lines)


var _registry: ContentRegistry
var _schemas: Dictionary = {}
var _validator := SchemaValidator.new()


func _init(registry: ContentRegistry) -> void:
	_registry = registry


func schemas() -> Dictionary:
	return _schemas


## Loads the base game plus every mod in [param mods_path], in resolved order.
func load_all(base_path: String = BASE_CONTENT_PATH, mods_path: String = MODS_PATH) -> LoadReport:
	var report := LoadReport.new()

	var base_manifest: ModManifest = ModLoader.read_manifest(base_path)
	if base_manifest == null:
		report.issues.append(
			ValidationIssue.error(
				base_path.path_join("manifest.json"),
				"$",
				"manifest",
				"base content has no manifest; the base game is loaded as a mod and needs one"
			)
		)
		return report

	var mods: Array[ModManifest] = ModLoader.discover(mods_path)
	var resolution: ModLoader.Resolution = ModLoader.resolve(mods)
	report.disabled_sources = resolution.disabled
	for message: String in resolution.errors:
		report.issues.append(ValidationIssue.error(mods_path, "$", "dependencies", message))

	var ordered: Array[ModManifest] = [base_manifest]
	ordered.append_array(resolution.order)

	# Schemas first, from every source, so that a mod may introduce a new definition type
	# that another mod's content then uses.
	for manifest: ModManifest in ordered:
		_load_schemas(manifest, report)
	for manifest: ModManifest in ordered:
		_load_definitions(manifest, report)
		report.sources.append(manifest.id)

	return report


func _load_schemas(manifest: ModManifest, report: LoadReport) -> void:
	var schemas_path: String = manifest.directory.path_join("schemas")
	var dir: DirAccess = DirAccess.open(schemas_path)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".schema.json"):
			continue
		var path: String = schemas_path.path_join(file_name)
		var parsed: Variant = _read_json(path, report)
		if not parsed is Dictionary:
			continue
		var type_name: String = file_name.replace(".schema.json", "")
		_schemas[type_name] = parsed


func _load_definitions(manifest: ModManifest, report: LoadReport) -> void:
	var definitions_path: String = manifest.directory.path_join("definitions")
	var root: DirAccess = DirAccess.open(definitions_path)
	if root == null:
		return
	var type_dirs: PackedStringArray = root.get_directories()
	type_dirs.sort()
	for type_name: String in type_dirs:
		var type_path: String = definitions_path.path_join(type_name)
		var folder: DirAccess = DirAccess.open(type_path)
		if folder == null:
			continue
		var files: PackedStringArray = folder.get_files()
		files.sort()
		for file_name: String in files:
			if not file_name.ends_with(".json"):
				continue
			_load_one(type_path.path_join(file_name), type_name, manifest, report)


func _load_one(
	path: String, folder_type: String, manifest: ModManifest, report: LoadReport
) -> void:
	var parsed: Variant = _read_json(path, report)
	if parsed == null:
		report.rejected_count += 1
		return
	if not parsed is Dictionary:
		report.issues.append(
			ValidationIssue.error(path, "$", "type", "a definition must be a JSON object")
		)
		report.rejected_count += 1
		return

	var data: Dictionary = parsed
	var declared_type: String = str(data.get("type", ""))
	if declared_type != folder_type:
		report.issues.append(
			ValidationIssue.error(
				path,
				"$.type",
				"type",
				"lives in definitions/%s/ but declares type '%s'" % [folder_type, declared_type]
			)
		)
		report.rejected_count += 1
		return

	if not _schemas.has(declared_type):
		report.issues.append(
			ValidationIssue.error(
				path,
				"$.type",
				"schema",
				"no schema for type '%s' in any loaded source" % declared_type
			)
		)
		report.rejected_count += 1
		return

	var issues: Array[ValidationIssue] = _validator.validate(data, _schemas[declared_type], path)
	# A new id must live in this source's namespace. An id in someone else's namespace
	# is an override -- legitimate, and the point of the override mechanism -- but only
	# of something that actually exists. Otherwise a typo silently squats on a name the
	# real owner may add later.
	var definition_id: String = str(data.get("id", ""))
	if (
		not definition_id.begins_with(manifest.id + ":")
		and not _registry.has(StringName(definition_id))
	):
		(
			issues
			. append(
				(
					ValidationIssue
					. error(
						path,
						"$.id",
						"namespace",
						(
							"id '%s' is neither namespaced to '%s' nor an override of an existing definition"
							% [definition_id, manifest.id]
						)
					)
				)
			)
		)

	if not issues.is_empty():
		report.issues.append_array(issues)
		report.rejected_count += 1
		return

	_registry.install(ContentDefinition.from_data(data, manifest.id))
	report.loaded_count += 1


func _read_json(path: String, report: LoadReport) -> Variant:
	if not FileAccess.file_exists(path):
		report.issues.append(ValidationIssue.error(path, "$", "file", "file does not exist"))
		return null
	var json := JSON.new()
	var text: String = FileAccess.get_file_as_string(path)
	if json.parse(text) != OK:
		report.issues.append(
			ValidationIssue.error(
				path,
				"$",
				"json",
				"invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]
			)
		)
		return null
	return json.data
