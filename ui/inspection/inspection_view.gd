class_name InspectionView
extends Control

## The most important interaction in the game.
##
## Two hands: one artifact, one tool. Free rotation, continuous zoom, crisp text at any
## magnification, a counter you can set things down on -- and no pause. The world keeps
## running while you look, which is the entire tension.
##
## There is no checklist overlay. If the player wants a checklist, the game gives them a
## laminated card taped to the register and lets them learn to stop needing it.

signal verdict_chosen(verdict: int)
signal tool_swapped(tool_id: String)

const ROTATION_SPEED: float = 0.006
const ZOOM_STEP: float = 0.35

var settings: GameSettings
var registry: ContentRegistry
var encounter: Encounter
var held_tools: PackedStringArray = []

var _renderer: DocumentRenderer
var _pivot: Control
var _tilt := Vector2.ZERO
var _seconds_spent: float = 0.0


func setup(p_settings: GameSettings, p_registry: ContentRegistry) -> void:
	settings = p_settings
	registry = p_registry
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# The room keeps running behind this; it is dimmed, never paused.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_pivot = Control.new()
	_pivot.anchor_left = 0.5
	_pivot.anchor_right = 0.5
	_pivot.anchor_top = 0.5
	_pivot.anchor_bottom = 0.5
	_pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pivot)

	var hint := Label.new()
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -64.0
	hint.offset_bottom = -24.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = (
		"hold right mouse to turn it over · wheel to look closer · F flips"
		+ " · 1 approve  2 decline  3 partial"
	)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.85, 0.84, 0.82))
	add_child(hint)

	_renderer = DocumentRenderer.new()
	_renderer.position = -DocumentRenderer.CARD_SIZE * 0.5
	_pivot.add_child(_renderer)
	visible = false


## Picks the artifact up. What the player sees first is the thing in their hands, not a
## list of its properties.
func present(p_encounter: Encounter, tools: PackedStringArray) -> void:
	encounter = p_encounter
	held_tools = tools.duplicate()
	_seconds_spent = 0.0
	_tilt = Vector2.ZERO
	var artifact: Artifact = encounter.primary_artifact()
	if artifact == null:
		return
	_renderer.setup(artifact, registry.get_definition(artifact.document_type_id), registry)
	_renderer.set_tools(held_tools)
	visible = true


func put_down() -> void:
	visible = false
	encounter = null


## Reaching for a tool is a real action with a real cost: your hands are finite, and
## picking up the loupe means putting down the torch.
func use_tool(tool_id: String) -> void:
	if not held_tools.has(tool_id):
		held_tools.append(tool_id)
	_renderer.set_tools(held_tools)
	var tool: ContentDefinition = registry.get_definition(StringName(tool_id))
	if tool != null:
		_seconds_spent += tool.get_number("inspection_seconds", 0.0)
	tool_swapped.emit(tool_id)


func seconds_spent() -> float:
	return _seconds_spent


func tools_in_hand() -> PackedStringArray:
	return held_tools.duplicate()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion and Input.is_action_pressed("inspect"):
		var motion: InputEventMouseMotion = event
		# Free rotation, no snapping to canonical angles: tilting it to catch the light
		# is how a hologram gets checked, and the game should not do that for you.
		_tilt.x = clampf(_tilt.x - motion.relative.y * ROTATION_SPEED, -0.9, 0.9)
		_tilt.y = clampf(_tilt.y + motion.relative.x * ROTATION_SPEED, -0.9, 0.9)
		_pivot.rotation = _tilt.y * 0.35
		_pivot.scale = Vector2.ONE * (1.0 - absf(_tilt.x) * 0.15)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_renderer.set_zoom(_renderer.zoom + ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_renderer.set_zoom(_renderer.zoom - ZOOM_STEP)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	if event.is_action("flip_artifact"):
		_renderer.flip()
	elif event.is_action("verdict_approve"):
		verdict_chosen.emit(Encounter.Verdict.APPROVE)
	elif event.is_action("verdict_decline"):
		verdict_chosen.emit(Encounter.Verdict.DECLINE)
	elif event.is_action("verdict_partial"):
		verdict_chosen.emit(Encounter.Verdict.PARTIAL)
	elif event.is_action("put_down"):
		put_down()
