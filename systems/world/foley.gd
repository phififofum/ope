class_name Foley
extends Node

## Every sound the shop makes, synthesised at startup.
##
## I previously wrote that audio was "asset-shaped work" and shipped the game silent.
## That was wrong: a till beep is two sine waves and an envelope, a pack tearing is
## filtered noise, and a door chime is a struck bar. None of it needs a recording, and a
## shop that makes no noise at all is the single loudest signal that a game is unfinished.
##
## Samples are built once into [AudioStreamWAV] buffers and played through a small pool,
## so the running cost is the same as any other sound effect. The settings screen's
## "a visual cue for every sound" promise still holds -- these are additions to the cues,
## never replacements for them.

const RATE: int = 22050
const VOICES: int = 12

var _samples: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _room_tone: AudioStreamPlayer
var _settings: GameSettings


func _init(settings: GameSettings = null) -> void:
	_settings = settings
	name = "Foley"


func _ready() -> void:
	for index: int in range(VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Master"
		add_child(voice)
		_voices.append(voice)

	_samples["till"] = _render(0.16, _till)
	_samples["chime"] = _render(1.1, _chime)
	_samples["page"] = _render(0.3, _page)
	_samples["rip"] = _render(0.55, _rip)
	_samples["thunk"] = _render(0.18, _thunk)
	_samples["step"] = _render(0.12, _step)
	_samples["sizzle"] = _render(0.9, _sizzle)
	_samples["meow"] = _render(0.5, _meow)
	_samples["stamp"] = _render(0.22, _stamp)
	_samples["refuse"] = _render(0.4, _refuse)
	_samples["coins"] = _render(0.5, _coins)

	_room_tone = AudioStreamPlayer.new()
	var tone: AudioStreamWAV = _render(2.0, _hum)
	tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tone.loop_begin = 0
	tone.loop_end = int(2.0 * float(RATE)) - 1
	_room_tone.stream = tone
	_room_tone.volume_db = -26.0
	add_child(_room_tone)
	_room_tone.play()


## Plays a sample by name. [param pitch] varies it so the twentieth till beep of the day
## is not audibly the same recording as the first.
func play(sample: String, volume_db: float = -8.0, pitch: float = 1.0) -> void:
	if not _samples.has(sample):
		return
	# The accessibility settings own the volume; silence is a supported way to play, and
	# every one of these has a visual counterpart in the HUD.
	var master: float = 1.0 if _settings == null else _settings.master_volume
	if master <= 0.01:
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _samples[sample]
	voice.volume_db = volume_db + linear_to_db(clampf(master, 0.01, 1.0))
	voice.pitch_scale = clampf(pitch, 0.4, 2.4)
	voice.play()


## The room gets louder as it fills. A busy shop should sound busy before you turn round
## and count the queue.
func set_occupancy(customers: int) -> void:
	if _room_tone == null:
		return
	var master: float = 1.0 if _settings == null else _settings.master_volume
	_room_tone.volume_db = (
		clampf(-30.0 + float(customers) * 1.4, -30.0, -14.0)
		+ linear_to_db(clampf(master, 0.01, 1.0))
	)


## Subscribes to the bus so the world makes noise without any system knowing it does.
func listen_to(bus: EventBus) -> void:
	bus.subscribe(
		EventCatalog.CUSTOMER_SPAWNED,
		func(_p: Dictionary) -> void: play("chime", -14.0, randf_range(0.97, 1.03)),
		"foley"
	)
	bus.subscribe(
		EventCatalog.CUSTOMER_SERVED,
		func(_p: Dictionary) -> void: play("till", -11.0, randf_range(0.95, 1.06)),
		"foley"
	)
	bus.subscribe(
		EventCatalog.PACK_OPENED,
		func(payload: Dictionary) -> void:
			play("rip", -6.0, randf_range(0.9, 1.1))
			# A hit is worth hearing. This is the only sound in the game that is a reward.
			if float(payload.get("best_value", 0.0)) >= 60.0:
				play("coins", -7.0, 1.0),
		"foley"
	)
	bus.subscribe(
		EventCatalog.ORDER_COMPLETED,
		func(_p: Dictionary) -> void: play("sizzle", -16.0, randf_range(0.92, 1.08)),
		"foley"
	)
	bus.subscribe(
		EventCatalog.CAT_FED,
		func(_p: Dictionary) -> void: play("meow", -12.0, randf_range(0.9, 1.15)),
		"foley"
	)
	bus.subscribe(
		EventCatalog.STRIKE_ISSUED, func(_p: Dictionary) -> void: play("refuse", -8.0, 1.0), "foley"
	)
	bus.subscribe(
		EventCatalog.VERIFICATION_RESOLVED,
		func(payload: Dictionary) -> void:
			# The stamp is the sound of a decision being made, and it lands whichever way
			# the decision went.
			play("stamp", -12.0, 0.9 if str(payload.get("verdict", "")) == "approve" else 1.25),
		"foley"
	)


# --- the synthesis ---------------------------------------------------------------
#
# Each of these returns one sample in [-1, 1] for a moment in time. Keeping them as pure
# functions of t is what makes them legible: an envelope times a timbre, and nothing else.


## Two short square-ish blips: a till acknowledging a barcode.
func _till(t: float, length: float) -> float:
	var phase: float = 1.0 if t < length * 0.45 else 1.32
	var envelope: float = _pluck(t, length, 90.0)
	return signf(sin(t * TAU * 880.0 * phase)) * 0.28 * envelope


## A struck bar over the door: a fundamental, a fifth, and a long decay.
func _chime(t: float, length: float) -> float:
	var envelope: float = exp(-t * 3.4) * clampf(t * 260.0, 0.0, 1.0)
	var body: float = (
		sin(t * TAU * 1046.0) * 0.5 + sin(t * TAU * 1568.0) * 0.32 + sin(t * TAU * 2093.0) * 0.18
	)
	return body * envelope * (1.0 - t / length * 0.2)


## Paper: a noise burst shaped so it is a rustle rather than a hiss.
func _page(t: float, length: float) -> float:
	var envelope: float = exp(-t * 14.0) * clampf(t * 400.0, 0.0, 1.0)
	return _noise(t * 7919.0) * envelope * 0.5 * (1.0 - t / length)


## Cellophane tearing: noise that rises in pitch and brightness as the wrapper opens.
func _rip(t: float, length: float) -> float:
	var progress: float = t / length
	var envelope: float = sin(progress * PI) * (0.6 + 0.4 * progress)
	var crackle: float = _noise(t * (5000.0 + 9000.0 * progress))
	var tear: float = _noise(t * 320.0)
	return (crackle * 0.7 + tear * 0.3) * envelope * 0.55


## Something set down on a wooden counter.
func _thunk(t: float, length: float) -> float:
	var envelope: float = _pluck(t, length, 55.0)
	return (sin(t * TAU * 110.0) * 0.6 + _noise(t * 2200.0) * 0.4) * envelope * 0.5


func _step(t: float, length: float) -> float:
	return _noise(t * 1400.0) * _pluck(t, length, 120.0) * 0.22


## A griddle: broadband noise with a slow swell, nothing tonal in it at all.
func _sizzle(t: float, length: float) -> float:
	var envelope: float = sin(clampf(t / length, 0.0, 1.0) * PI)
	return (_noise(t * 11000.0) * 0.7 + _noise(t * 3100.0) * 0.3) * envelope * 0.32


## A cat. Two formants sliding down over a sawtooth, which is close enough.
func _meow(t: float, length: float) -> float:
	var progress: float = t / length
	var pitch: float = 620.0 - 180.0 * progress
	var voice: float = fmod(t * pitch, 1.0) * 2.0 - 1.0
	var formant: float = sin(t * TAU * (1100.0 - 300.0 * progress)) * 0.4
	return (voice * 0.5 + formant) * sin(progress * PI) * 0.35


## The rubber stamp on the ledger: the sound of a verdict.
func _stamp(t: float, length: float) -> float:
	var envelope: float = _pluck(t, length, 70.0)
	return (_noise(t * 900.0) * 0.5 + sin(t * TAU * 180.0) * 0.5) * envelope * 0.6


## A buzzer. Deliberately unpleasant: this is what a strike sounds like.
func _refuse(t: float, length: float) -> float:
	var envelope: float = clampf(1.0 - t / length, 0.0, 1.0) * clampf(t * 120.0, 0.0, 1.0)
	return signf(sin(t * TAU * 196.0)) * 0.22 * envelope


## Money. A handful of short metallic partials at staggered times.
func _coins(t: float, length: float) -> float:
	var total: float = 0.0
	for index: int in range(5):
		var start: float = float(index) * 0.055
		if t < start:
			continue
		var age: float = t - start
		total += sin(age * TAU * (2400.0 + 430.0 * float(index))) * exp(-age * 22.0)
	return clampf(total * 0.24, -1.0, 1.0) * (1.0 - t / length * 0.3)


## Room tone: a fridge, a fan, and the building. Two detuned low sines plus filtered
## noise, which is what quiet actually sounds like indoors.
func _hum(t: float, _length: float) -> float:
	var mains: float = sin(t * TAU * 50.0) * 0.5 + sin(t * TAU * 50.6) * 0.3
	var air: float = _noise(t * 90.0) * 0.5 + _noise(t * 17.0) * 0.5
	return mains * 0.22 + air * 0.18


## A percussive envelope: instant attack, exponential decay.
func _pluck(t: float, length: float, decay: float) -> float:
	return exp(-t * decay) * clampf((length - t) * 60.0, 0.0, 1.0)


## Deterministic value noise. Not white noise -- it is smooth between samples, which
## sounds like material rather than like static.
func _noise(x: float) -> float:
	var i: int = int(x)
	var f: float = x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(i), _hash(i + 1), f) * 2.0 - 1.0


func _hash(x: int) -> float:
	var h: int = (x * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) * 668265263
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


## Renders one voice function into a 16-bit mono buffer.
func _render(length: float, voice: Callable) -> AudioStreamWAV:
	var frames: int = int(length * float(RATE))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for frame: int in range(frames):
		var t: float = float(frame) / float(RATE)
		var value: float = clampf(float(voice.call(t, length)), -1.0, 1.0)
		var sample: int = int(value * 32767.0)
		data.encode_s16(frame * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
