class_name SettingsMenu
extends Control

## Settings, with accessibility on the first screen rather than three menus deep.
##
## Two of these are load-bearing and neither is hidden: the memory assist, which surfaces
## active rules at the counter without penalty, and the reading font, which substitutes
## the face while preserving the typographic differences that make "wrong font for this
## jurisdiction" a detectable forgery.

signal closed

var settings: GameSettings

var _rows: VBoxContainer


func setup(p_settings: GameSettings) -> void:
	settings = p_settings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.09, 0.08, 0.1, 0.98)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(760.0, 0.0)
	_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows)

	_heading("Accessibility")
	_toggle("Subtitles", settings.subtitles, func(v: bool) -> void: settings.subtitles = v)
	_toggle(
		"Speaker labels on subtitles",
		settings.subtitle_speaker_labels,
		func(v: bool) -> void: settings.subtitle_speaker_labels = v
	)
	_toggle(
		"Direction indicators for off-screen sound",
		settings.directional_audio_indicators,
		func(v: bool) -> void: settings.directional_audio_indicators = v
	)
	_toggle(
		"A visible cue for every sound",
		settings.visual_cue_for_every_sound,
		func(v: bool) -> void: settings.visual_cue_for_every_sound = v
	)
	_toggle(
		"Shapes as well as colour (always on for verification cues)",
		settings.shapes_as_well_as_colour,
		func(v: bool) -> void: settings.shapes_as_well_as_colour = v
	)
	_option(
		"Colourblind mode",
		["None", "Protanopia", "Deuteranopia", "Tritanopia"],
		settings.colourblind_mode,
		func(v: int) -> void: settings.colourblind_mode = v as GameSettings.ColourblindMode
	)
	_toggle(
		"Reading font (keeps typeface differences legible)",
		settings.reading_font,
		func(v: bool) -> void: settings.reading_font = v
	)
	_toggle(
		"Memory assist: show the rules that apply at the counter",
		settings.memory_assist,
		func(v: bool) -> void: settings.memory_assist = v
	)
	_slider(
		"Timer tolerance",
		settings.timer_tolerance,
		1.0,
		2.5,
		func(v: float) -> void: settings.timer_tolerance = v
	)
	_slider(
		"Interface scale",
		settings.ui_scale,
		1.0,
		2.0,
		func(v: float) -> void: settings.ui_scale = v
	)
	_toggle("Head bob", settings.head_bob, func(v: bool) -> void: settings.head_bob = v)
	_toggle("Camera shake", settings.camera_shake, func(v: bool) -> void: settings.camera_shake = v)
	_toggle(
		"Hold to inspect (off makes it a toggle, for one-handed play)",
		settings.hold_to_inspect,
		func(v: bool) -> void: settings.hold_to_inspect = v
	)

	_heading("Controls")
	_slider(
		"Look sensitivity",
		settings.look_sensitivity,
		0.2,
		3.0,
		func(v: float) -> void: settings.look_sensitivity = v
	)
	_toggle(
		"Invert look", settings.invert_look_y, func(v: bool) -> void: settings.invert_look_y = v
	)
	_slider(
		"Field of view",
		settings.field_of_view,
		60.0,
		110.0,
		func(v: float) -> void: settings.field_of_view = v
	)

	_heading("Difficulty")
	_option(
		"Preset",
		["relaxed", "standard", "tight", "brutal"],
		["relaxed", "standard", "tight", "brutal"].find(settings.difficulty_preset),
		func(v: int) -> void:
			settings.difficulty_preset = ["relaxed", "standard", "tight", "brutal"][v]
	)

	_heading("Audio")
	_slider(
		"Master",
		settings.master_volume,
		0.0,
		1.0,
		func(v: float) -> void: settings.master_volume = v
	)
	_slider(
		"Shop radio",
		settings.music_volume,
		0.0,
		1.0,
		func(v: float) -> void: settings.music_volume = v
	)

	var close := Button.new()
	close.text = "Back"
	close.pressed.connect(
		func() -> void:
			settings.save()
			closed.emit()
	)
	_rows.add_child(close)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(26 * settings.ui_scale))
	_rows.add_child(label)


func _toggle(text: String, value: bool, on_change: Callable) -> void:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = value
	box.toggled.connect(on_change)
	_rows.add_child(box)


func _slider(text: String, value: float, low: float, high: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(340.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 40.0
	slider.value = value
	slider.custom_minimum_size = Vector2(320.0, 0.0)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	_rows.add_child(row)


func _option(text: String, choices: Array, selected: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(340.0, 0.0)
	row.add_child(label)
	var button := OptionButton.new()
	for choice: String in choices:
		button.add_item(str(choice))
	button.selected = maxi(0, selected)
	button.item_selected.connect(on_change)
	row.add_child(button)
	_rows.add_child(row)
