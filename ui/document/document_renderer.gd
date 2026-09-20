class_name DocumentRenderer
extends Control

## Documents are not art assets. They are built at runtime from a [code]document_type[/code]
## definition as a Control hierarchy: vector layout, real text, procedural security
## features, procedural wear.
##
## This is the highest-leverage decision in the art pipeline. It gives crisp text at any
## zoom -- which matters because the player is asked to look closely -- it makes every
## forgery vector a data-driven transform rather than a hand-drawn variant, and it means
## a modder adds a document type in JSON without opening an image editor.
##
## What is visible depends on the tools in the player's hands. The UV overlay is not
## dimmed without a torch; it is not drawn.

const CARD_SIZE := Vector2(860.0, 540.0)
const MICROPRINT_ZOOM: float = 2.2

var artifact: Artifact
var document_type: ContentDefinition
var held_tools: PackedStringArray = []
var zoom: float = 1.0
var show_back: bool = false

var _registry: ContentRegistry


func setup(
	p_artifact: Artifact, p_document_type: ContentDefinition, p_registry: ContentRegistry
) -> void:
	artifact = p_artifact
	document_type = p_document_type
	_registry = p_registry
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	clip_contents = true
	rebuild()


func set_tools(tools: PackedStringArray) -> void:
	held_tools = tools
	rebuild()


func set_zoom(new_zoom: float) -> void:
	zoom = clampf(new_zoom, 1.0, 6.0)
	rebuild()


func flip() -> void:
	show_back = not show_back
	rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	if artifact == null or document_type == null:
		return

	var face: String = "back" if show_back else "front"
	var background := ColorRect.new()
	background.color = Color(0.93, 0.92, 0.88)
	background.size = CARD_SIZE
	add_child(background)

	# Print wear and process artefacts: a photocopied document looks photocopied, and
	# that is a data-driven transform rather than a second hand-drawn asset.
	if str(artifact.field("_process", "")) == "photocopy_generation":
		var wash := ColorRect.new()
		wash.color = Color(0.78, 0.78, 0.8, 0.35)
		wash.size = CARD_SIZE
		add_child(wash)

	var rows := VBoxContainer.new()
	rows.position = Vector2(36.0, 28.0)
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)

	var title := Label.new()
	title.text = _title_text()
	title.add_theme_font_size_override("font_size", int(30.0 * zoom))
	title.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16))
	rows.add_child(title)

	for field_spec: Dictionary in document_type.get_value("fields", []):
		if str(field_spec.get("face", "front")) != face:
			continue
		var required_tool: String = str(field_spec.get("revealed_by", ""))
		if not required_tool.is_empty() and not held_tools.has(required_tool):
			continue  # not dimmed: absent, because you have no instrument for it
		rows.add_child(_field_row(field_spec))

	for feature_spec: Dictionary in document_type.get_value("security_features", []):
		var feature_id: String = str(feature_spec.get("id", ""))
		if not held_tools.has(str(feature_spec.get("revealed_by", ""))):
			continue
		add_child(_feature_overlay(feature_id))


func _title_text() -> String:
	var jurisdiction: String = document_type.get_text("jurisdiction", "")
	var family: String = document_type.get_text("family", "document")
	var label: String = (jurisdiction if not jurisdiction.is_empty() else family).to_upper()
	# Typeface is itself a forgery tell, so a near-miss face is rendered, not annotated.
	return label + ("  ·  " if artifact.typeface.ends_with("_near_miss") else "  ")


func _field_row(field_spec: Dictionary) -> Control:
	var key: String = str(field_spec.get("key", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = key.replace("_", " ").to_upper()
	label.add_theme_font_size_override("font_size", int(15.0 * zoom))
	label.modulate = Color(0.35, 0.35, 0.38)
	row.add_child(label)

	var value := Label.new()
	value.text = _format_value(key, artifact.field(key, ""))
	value.add_theme_font_size_override("font_size", int(21.0 * zoom))
	value.add_theme_color_override("font_color", Color(0.1, 0.1, 0.13))
	row.add_child(value)
	return row


func _format_value(key: String, raw: Variant) -> String:
	if raw == null:
		return "—"
	# Dates are stored as days since the world epoch; a player reads a date.
	if (
		key in ["dob", "expiry", "issued", "date", "holding_period_ends"]
		and (raw is int or raw is float)
	):
		return _format_date(int(raw))
	return str(raw)


func _format_date(days: int) -> String:
	var year: int = ForgeryGenerator.EPOCH_YEAR + int(floor(float(days) / 365.25))
	var day_of_year: int = days - int(floor(float(days) / 365.25) * 365.25)
	var month: int = clampi(1 + int(float(day_of_year) / 30.5), 1, 12)
	var day: int = clampi(1 + day_of_year - int((month - 1) * 30.5), 1, 28)
	return "%02d/%02d/%04d" % [month, day, year]


## Security features are drawn only when the instrument that reveals them is in hand --
## and a missing one is drawn as nothing at all, which is exactly what the player has to
## notice.
func _feature_overlay(feature_id: String) -> Control:
	var overlay := Control.new()
	overlay.size = CARD_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not artifact.has_feature(feature_id):
		return overlay

	match feature_id:
		"uv_seal", "foil_response":
			var seal := ColorRect.new()
			seal.color = Color(0.45, 0.25, 0.95, 0.5)
			seal.size = Vector2(150.0, 150.0)
			seal.position = Vector2(CARD_SIZE.x - 200.0, CARD_SIZE.y - 200.0)
			overlay.add_child(seal)
		"microprint_border", "print_rosette", "carbon_impression":
			# Microprint is legible only when magnified: the loupe reveals that there is
			# something there, and the zoom reveals whether it says anything.
			var border := Label.new()
			border.text = (
				("PROVINCE OF " + document_type.get_text("jurisdiction", "NORTHVALE")).repeat(6)
				if zoom >= MICROPRINT_ZOOM
				else "·".repeat(120)
			)
			border.add_theme_font_size_override("font_size", maxi(4, int(5.0 * zoom)))
			border.add_theme_color_override("font_color", Color(0.2, 0.2, 0.26))
			border.position = Vector2(24.0, CARD_SIZE.y - 40.0)
			overlay.add_child(border)
		"layer_core":
			var core := ColorRect.new()
			core.color = Color(0.1, 0.1, 0.12, 0.25)
			core.size = Vector2(CARD_SIZE.x - 60.0, 8.0)
			core.position = Vector2(30.0, CARD_SIZE.y * 0.5)
			overlay.add_child(core)
	return overlay
