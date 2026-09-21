class_name MainMenu
extends Control

## The front door. Four choices and a settings screen, because a menu is not where this
## game is interesting.

signal play_requested(session_seed: int)
signal rush_requested
signal settings_requested
signal quit_requested

var settings: GameSettings

var _status: Label


func setup(p_settings: GameSettings) -> void:
	settings = p_settings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.08, 0.07, 0.09)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position = Vector2(-220.0, -200.0)
	column.custom_minimum_size = Vector2(440.0, 0.0)
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var title := Label.new()
	title.text = "PoggyWoggy"
	title.add_theme_font_size_override("font_size", int(64 * settings.ui_scale))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A late-night board game cafe. The hard part is knowing what to check."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", int(18 * settings.ui_scale))
	column.add_child(subtitle)

	column.add_child(_button("Open the shop", func() -> void: play_requested.emit(randi())))
	# Rush mode is the recommended on-ramp for a group who have never played: one loop,
	# twenty-five minutes, no campaign commitment.
	column.add_child(_button("Rush mode (kitchen only)", func() -> void: rush_requested.emit()))
	column.add_child(_button("Settings", func() -> void: settings_requested.emit()))
	column.add_child(_button("Quit", func() -> void: quit_requested.emit()))

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", int(14 * settings.ui_scale))
	_status.modulate = Color(0.6, 0.6, 0.65)
	column.add_child(_status)
	set_status(Game.status_line())


## Re-applies the interface scale after a settings change, so the accessibility slider
## takes effect without a restart.
func apply_settings_scale() -> void:
	for child: Node in get_children():
		if child is Control:
			(child as Control).scale = Vector2.ONE * settings.ui_scale


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0 * settings.ui_scale)
	button.pressed.connect(on_press)
	return button
