class_name SeededRng
extends RefCounted

## Named, seeded random streams.
##
## Every piece of gameplay randomness draws from a named stream rather than a global
## generator. Two properties fall out of that, and both are load-bearing:
##
## [b]Reproducibility.[/b] A save plus an input log replays a session exactly, which is what
## makes headless integration tests and multiplayer desync debugging possible.
##
## [b]Independence.[/b] Drawing from [code]spawn[/code] never shifts [code]forgery[/code].
## Without that, adding one customer spawn changes every forgery in the run, and a bug
## report stops being reproducible the moment anything upstream changes.

## The streams the base game draws from. A mod may open its own by any other name;
## these are named so that a typo in base code fails a test rather than silently
## opening a new stream.
const SPAWN: StringName = &"spawn"
const FORGERY: StringName = &"forgery"
const CAT_MOOD: StringName = &"cat_mood"
const BREAKAGE: StringName = &"breakage"
const MARKET: StringName = &"market"
const PULL_RATES: StringName = &"pull_rates"
const STAFF_ERROR: StringName = &"staff_error"

var _session_seed: int
var _streams: Dictionary = {}


func _init(session_seed: int = 0) -> void:
	_session_seed = session_seed


func session_seed() -> int:
	return _session_seed


## Returns the generator for [param stream_name], creating it on first use. The seed is
## derived from the session seed and the name, so streams are independent and a stream
## opened later in the run still produces the same sequence.
func stream(stream_name: StringName) -> RandomNumberGenerator:
	if _streams.has(stream_name):
		return _streams[stream_name]
	var generator := RandomNumberGenerator.new()
	generator.seed = _derive_seed(stream_name)
	_streams[stream_name] = generator
	return generator


func _derive_seed(stream_name: StringName) -> int:
	# hash() alone collides too readily across short names; mixing it with the session
	# seed through a large odd multiplier spreads streams apart. The constant is the
	# xorshift* multiplier, which fits in a signed 64-bit integer.
	var name_hash: int = String(stream_name).hash()
	return (_session_seed ^ (name_hash * 0x2545F4914F6CDD1D)) & 0x7FFFFFFFFFFFFFFF


## Serialises every open stream, including how far each has advanced, so a save
## resumes mid-run without repeating numbers.
func snapshot() -> Dictionary:
	var streams: Dictionary = {}
	for stream_name: StringName in _streams.keys():
		var generator: RandomNumberGenerator = _streams[stream_name]
		streams[String(stream_name)] = {"seed": generator.seed, "state": generator.state}
	return {"session_seed": _session_seed, "streams": streams}


func restore(snapshot_data: Dictionary) -> void:
	_session_seed = int(snapshot_data.get("session_seed", 0))
	_streams.clear()
	var streams: Dictionary = snapshot_data.get("streams", {})
	for stream_name: String in streams.keys():
		var entry: Dictionary = streams[stream_name]
		var generator := RandomNumberGenerator.new()
		generator.seed = int(entry.get("seed", 0))
		generator.state = int(entry.get("state", 0))
		_streams[StringName(stream_name)] = generator


## Picks one element, deterministically, from [param options].
func pick(stream_name: StringName, options: Array) -> Variant:
	if options.is_empty():
		return null
	var index: int = stream(stream_name).randi_range(0, options.size() - 1)
	return options[index]


## Weighted pick. [param weights] must be the same length as [param options]; entries at
## or below zero are treated as unpickable rather than as an error, because content is
## data and data gets typed by hand.
func pick_weighted(stream_name: StringName, options: Array, weights: Array) -> Variant:
	if options.is_empty() or options.size() != weights.size():
		return null
	var total: float = 0.0
	for weight: float in weights:
		total += maxf(0.0, weight)
	if total <= 0.0:
		return null
	var roll: float = stream(stream_name).randf() * total
	var cursor: float = 0.0
	for index: int in range(options.size()):
		cursor += maxf(0.0, float(weights[index]))
		if roll < cursor:
			return options[index]
	return options[options.size() - 1]
