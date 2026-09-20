class_name Boot
extends Control

## Phase 0 boot scene: load every content definition, report what was found, and
## exit non-zero if anything is missing.
##
## This is the smallest artifact that proves the whole chain works — content on
## disk, a build that can read it, and a window that renders. It is what gets
## exported and uploaded to a Steam playtest branch before any gameplay exists.
##
## Run it headless the way CI does:
##     godot --headless --path . -- --smoke-test

const CONTENT_ROOT: String = "res://content"
const SMOKE_TEST_FLAG: String = "--smoke-test"

var _counts: Dictionary = {}
var _errors: PackedStringArray = []
var _manifest: Dictionary = {}


func _ready() -> void:
	_manifest = _load_manifest()
	_counts = _load_definitions()

	var report: String = _format_report()
	print(report)

	if not _is_headless():
		_build_screen(report)

	if _smoke_test_requested():
		get_tree().quit(1 if _errors.size() > 0 else 0)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _smoke_test_requested() -> bool:
	return OS.get_cmdline_user_args().has(SMOKE_TEST_FLAG)


func _load_manifest() -> Dictionary:
	var path: String = CONTENT_ROOT + "/manifest.json"
	var parsed: Variant = _read_json(path)
	if parsed is Dictionary:
		return parsed as Dictionary
	_errors.append("content manifest missing or malformed: " + path)
	return {}


func _load_definitions() -> Dictionary:
	var counts: Dictionary = {}
	var definitions_root: String = CONTENT_ROOT + "/definitions"
	var root: DirAccess = DirAccess.open(definitions_root)
	if root == null:
		_errors.append("cannot open " + definitions_root)
		return counts

	for type_name: String in root.get_directories():
		var type_path: String = definitions_root + "/" + type_name
		var folder: DirAccess = DirAccess.open(type_path)
		if folder == null:
			_errors.append("cannot open " + type_path)
			continue
		var loaded: int = 0
		for file_name: String in folder.get_files():
			if not file_name.ends_with(".json"):
				continue
			var definition: Variant = _read_json(type_path + "/" + file_name)
			if definition is Dictionary and (definition as Dictionary).has("id"):
				loaded += 1
			else:
				_errors.append("malformed definition: " + type_path + "/" + file_name)
		counts[type_name] = loaded
	return counts


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func _total_definitions() -> int:
	var total: int = 0
	for type_name: String in _counts.keys():
		total += int(_counts[type_name])
	return total


func _format_report() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	var source_name: String = str(_manifest.get("name", "<none>"))
	var source_version: String = str(_manifest.get("version", ""))

	var lines: PackedStringArray = []
	lines.append("PoggyWoggy %s — Phase 0 boot" % version)
	lines.append("content source: %s %s" % [source_name, source_version])
	for type_name: String in _sorted_types():
		lines.append("  %4d  %s" % [int(_counts[type_name]), type_name])
	lines.append("  %4d  definitions total" % _total_definitions())
	for message: String in _errors:
		lines.append("  ERROR  " + message)
	return "\n".join(lines)


func _sorted_types() -> PackedStringArray:
	var types: PackedStringArray = []
	for type_name: String in _counts.keys():
		types.append(type_name)
	types.sort()
	return types


func _build_screen(report: String) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title: Label = Label.new()
	title.text = "PoggyWoggy"
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Phase 0 — the pipeline, before the game."
	subtitle.add_theme_font_size_override("font_size", 22)
	column.add_child(subtitle)

	var body: Label = Label.new()
	body.text = report
	body.add_theme_font_size_override("font_size", 18)
	column.add_child(body)
