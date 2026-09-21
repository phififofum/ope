class_name GameSettings
extends RefCounted

## Settings, with accessibility first because retrofitting it is expensive and because
## one of these options is load-bearing for the whole game.
##
## [b]No verification cue may depend on colour alone.[/b] Every colour-carried signal has
## a shape, pattern or text equivalent, and that is not a toggle -- the toggle only
## changes how loudly it is stated.
##
## The dyslexia-friendly font needs the same care: it substitutes the reading face while
## preserving relative typographic differences, because typeface is a forgery vector and
## flattening it would delete a mechanic.

enum ColourblindMode { NONE, PROTANOPIA, DEUTERANOPIA, TRITANOPIA }

const PATH: String = "user://settings.json"

var master_volume: float = 0.8
var music_volume: float = 0.4
var ui_scale: float = 1.0  ## 1.0 .. 2.0
var subtitles: bool = true
var subtitle_speaker_labels: bool = true
var directional_audio_indicators: bool = true
var visual_cue_for_every_sound: bool = false
var colourblind_mode: ColourblindMode = ColourblindMode.NONE
var shapes_as_well_as_colour: bool = true
var reading_font: bool = false
var head_bob: bool = true
var camera_shake: bool = true
var field_of_view: float = 75.0
var invert_look_y: bool = false
var look_sensitivity: float = 1.0
var hold_to_inspect: bool = true  ## false means toggle, for one-handed and switch play
var timer_tolerance: float = 1.0  ## 1.0 .. 2.5, a difficulty option rather than a ghetto
var memory_assist: bool = false  ## surfaces active rules at the counter, without penalty
var difficulty_preset: String = "standard"
var bindings: Dictionary = {}


static func load_from_disk() -> GameSettings:
	var settings := GameSettings.new()
	if not FileAccess.file_exists(PATH):
		return settings
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		settings.apply(parsed)
	return settings


func apply(data: Dictionary) -> void:
	master_volume = float(data.get("master_volume", master_volume))
	music_volume = float(data.get("music_volume", music_volume))
	ui_scale = clampf(float(data.get("ui_scale", ui_scale)), 1.0, 2.0)
	subtitles = bool(data.get("subtitles", subtitles))
	subtitle_speaker_labels = bool(data.get("subtitle_speaker_labels", subtitle_speaker_labels))
	directional_audio_indicators = bool(
		data.get("directional_audio_indicators", directional_audio_indicators)
	)
	visual_cue_for_every_sound = bool(
		data.get("visual_cue_for_every_sound", visual_cue_for_every_sound)
	)
	colourblind_mode = int(data.get("colourblind_mode", colourblind_mode)) as ColourblindMode
	shapes_as_well_as_colour = bool(data.get("shapes_as_well_as_colour", shapes_as_well_as_colour))
	reading_font = bool(data.get("reading_font", reading_font))
	head_bob = bool(data.get("head_bob", head_bob))
	camera_shake = bool(data.get("camera_shake", camera_shake))
	field_of_view = clampf(float(data.get("field_of_view", field_of_view)), 60.0, 110.0)
	invert_look_y = bool(data.get("invert_look_y", invert_look_y))
	look_sensitivity = clampf(float(data.get("look_sensitivity", look_sensitivity)), 0.2, 3.0)
	hold_to_inspect = bool(data.get("hold_to_inspect", hold_to_inspect))
	timer_tolerance = clampf(float(data.get("timer_tolerance", timer_tolerance)), 1.0, 2.5)
	memory_assist = bool(data.get("memory_assist", memory_assist))
	difficulty_preset = str(data.get("difficulty_preset", difficulty_preset))
	bindings = data.get("bindings", bindings)


func to_dictionary() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"ui_scale": ui_scale,
		"subtitles": subtitles,
		"subtitle_speaker_labels": subtitle_speaker_labels,
		"directional_audio_indicators": directional_audio_indicators,
		"visual_cue_for_every_sound": visual_cue_for_every_sound,
		"colourblind_mode": colourblind_mode,
		"shapes_as_well_as_colour": shapes_as_well_as_colour,
		"reading_font": reading_font,
		"head_bob": head_bob,
		"camera_shake": camera_shake,
		"field_of_view": field_of_view,
		"invert_look_y": invert_look_y,
		"look_sensitivity": look_sensitivity,
		"hold_to_inspect": hold_to_inspect,
		"timer_tolerance": timer_tolerance,
		"memory_assist": memory_assist,
		"difficulty_preset": difficulty_preset,
		"bindings": bindings,
	}


func save() -> bool:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary(), "  "))
	file.close()
	return true


## A cue's shape, so that no signal is carried by colour alone. Used by the HUD, the
## inspection view and the kitchen readouts, so there is one place to get it right.
func cue_shape(severity: String) -> String:
	if not shapes_as_well_as_colour:
		return ""
	match severity:
		"good":
			return "✔"
		"warning":
			return "▲"
		"bad":
			return "✖"
		"info":
			return "●"
	return ""


func cue_colour(severity: String) -> Color:
	# Palettes chosen to stay distinguishable under each common form of colour blindness;
	# the shape is what carries the meaning either way.
	match colourblind_mode:
		ColourblindMode.PROTANOPIA, ColourblindMode.DEUTERANOPIA:
			match severity:
				"good":
					return Color(0.25, 0.5, 0.95)
				"warning":
					return Color(0.95, 0.75, 0.2)
				"bad":
					return Color(0.15, 0.15, 0.2)
		ColourblindMode.TRITANOPIA:
			match severity:
				"good":
					return Color(0.2, 0.7, 0.45)
				"warning":
					return Color(0.9, 0.35, 0.5)
				"bad":
					return Color(0.55, 0.1, 0.25)
		_:
			match severity:
				"good":
					return Color(0.3, 0.75, 0.4)
				"warning":
					return Color(0.95, 0.7, 0.2)
				"bad":
					return Color(0.85, 0.25, 0.25)
	return Color(0.8, 0.8, 0.85)
