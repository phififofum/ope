class_name Boot
extends Control

## The boot screen: load all content through the real registry, report what was found,
## and exit non-zero if anything is wrong.
##
## It is deliberately the smallest thing that can be exported, installed by a tester and
## verified end to end. A green run here means content on disk, a build that can read it,
## a registry that indexes it and a window that renders — the whole chain, before there is
## any gameplay riding on it.
##
## Run it the way CI does:
##     godot --headless --path . -- --smoke-test

const SMOKE_TEST_FLAG: String = "--smoke-test"

var _report: ContentLoader.LoadReport


func _ready() -> void:
	_report = Game.boot()
	var text: String = _format_report()
	print(text)

	if not _is_headless():
		_build_screen(text)

	if _smoke_test_requested():
		get_tree().quit(1 if not _report.errors().is_empty() else 0)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _smoke_test_requested() -> bool:
	return OS.get_cmdline_user_args().has(SMOKE_TEST_FLAG)


func _format_report() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	var lines: PackedStringArray = []
	lines.append("PoggyWoggy %s — Phase 0 boot" % version)
	lines.append("content sources: %s" % ", ".join(_report.sources))
	for type_name: StringName in Game.registry.types():
		lines.append("  %4d  %s" % [Game.registry.count_of(type_name), type_name])
	lines.append("  %4d  definitions total" % Game.registry.size())
	for override: Dictionary in Game.registry.overrides():
		lines.append(
			(
				"  override  %s: %s wins over %s"
				% [override["id"], override["winning_source"], override["overridden_source"]]
			)
		)
	for issue: ValidationIssue in _report.issues:
		lines.append("  " + issue.to_text())
	for source_id: String in _report.disabled_sources.keys():
		lines.append("  DISABLED  %s: %s" % [source_id, _report.disabled_sources[source_id]])
	return "\n".join(lines)


func _build_screen(report_text: String) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "PoggyWoggy"
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Phase 0 — the pipeline, before the game."
	subtitle.add_theme_font_size_override("font_size", 22)
	column.add_child(subtitle)

	var body := Label.new()
	body.text = report_text
	body.add_theme_font_size_override("font_size", 18)
	column.add_child(body)
