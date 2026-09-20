class_name Hud
extends CanvasLayer

## The permitted non-diegetic layer, and it is deliberately almost nothing.
##
## If information can live in the world, it lives in the world. What is left here is an
## interaction prompt, what is in your hands, subtitles, and the accessibility layer that
## gives every audio cue a visible equivalent -- because the door chime and the kitchen
## timer are gameplay signals, not atmosphere.

const SUBTITLE_SECONDS: float = 3.5

var settings: GameSettings

var _prompt: Label
var _hands: Label
var _subtitle: Label
var _cues: VBoxContainer
var _memory_assist: VBoxContainer
var _subtitle_timer: float = 0.0


func setup(p_settings: GameSettings) -> void:
	settings = p_settings
	layer = 10

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_prompt = _label(root, 20, -190.0, HORIZONTAL_ALIGNMENT_CENTER)
	_hands = _label(root, 18, -58.0, HORIZONTAL_ALIGNMENT_LEFT)
	_subtitle = _label(root, 22, -110.0, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Visible equivalents for sounds: a door chime you cannot hear is a customer you
	# never knew arrived.
	_cues = VBoxContainer.new()
	_cues.anchor_left = 1.0
	_cues.anchor_right = 1.0
	_cues.offset_left = -340.0
	_cues.offset_right = -24.0
	_cues.offset_top = 24.0
	root.add_child(_cues)

	# The memory assist: active rules surfaced at the counter, offered plainly and
	# without penalty. It is a difficulty setting, and it is not buried.
	_memory_assist = VBoxContainer.new()
	_memory_assist.anchor_top = 0.35
	_memory_assist.offset_left = 28.0
	_memory_assist.offset_right = 360.0
	_memory_assist.visible = false
	root.add_child(_memory_assist)

	apply_settings()


func apply_settings() -> void:
	if settings == null:
		return
	for label: Label in [_prompt, _hands, _subtitle]:
		label.add_theme_font_size_override(
			"font_size", int(label.get_theme_font_size("font_size") * settings.ui_scale)
		)
	_subtitle.visible = settings.subtitles
	_memory_assist.visible = settings.memory_assist


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_hands(artifact_label: String, tool_label: String) -> void:
	var left: String = artifact_label if not artifact_label.is_empty() else "—"
	var right: String = tool_label if not tool_label.is_empty() else "—"
	_hands.text = "left: %s     right: %s" % [left, right]


## [param speaker] is shown when speaker labels are on, and [param direction] gives an
## off-screen arrow, because a subtitle that does not say who spoke or from where is only
## half a subtitle.
func say(speaker: String, line: String, direction: String = "") -> void:
	if not settings.subtitles:
		return
	var prefix: String = ""
	if settings.subtitle_speaker_labels and not speaker.is_empty():
		prefix = "%s: " % speaker
	var suffix: String = ""
	if settings.directional_audio_indicators and not direction.is_empty():
		suffix = "  (%s)" % direction
	_subtitle.text = prefix + line + suffix
	_subtitle_timer = SUBTITLE_SECONDS


## A cue the player must not miss. [param severity] picks the shape as well as the
## colour, so nothing here is carried by colour alone.
func cue(text: String, severity: String = "info", direction: String = "") -> void:
	if not settings.visual_cue_for_every_sound and severity == "info":
		return
	var line := Label.new()
	var shape: String = settings.cue_shape(severity)
	var arrow: String = " (%s)" % direction if not direction.is_empty() else ""
	line.text = "%s %s%s" % [shape, text, arrow]
	line.add_theme_color_override("font_color", settings.cue_colour(severity))
	line.add_theme_font_size_override("font_size", int(18 * settings.ui_scale))
	_cues.add_child(line)
	if _cues.get_child_count() > 5:
		_cues.get_child(0).queue_free()
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(
		func() -> void:
			if is_instance_valid(line):
				line.queue_free()
	)


func show_active_rules(rules: PackedStringArray) -> void:
	if not settings.memory_assist:
		return
	for child: Node in _memory_assist.get_children():
		child.queue_free()
	for rule_text: String in rules:
		var line := Label.new()
		line.text = "· " + rule_text
		line.add_theme_font_size_override("font_size", int(15 * settings.ui_scale))
		_memory_assist.add_child(line)
	_memory_assist.visible = true


func _process(delta: float) -> void:
	if _subtitle_timer > 0.0:
		_subtitle_timer -= delta
		if _subtitle_timer <= 0.0:
			_subtitle.text = ""


## Full-width, bottom-anchored labels. Anchors rather than positions, so the layout
## holds at any resolution and at any interface scale.
func _label(parent: Control, size: int, from_bottom: float, alignment: int) -> Label:
	var label := Label.new()
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 32.0
	label.offset_right = -32.0
	label.offset_top = from_bottom
	label.offset_bottom = from_bottom + 40.0
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = alignment as HorizontalAlignment
	label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.93))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.07))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label
