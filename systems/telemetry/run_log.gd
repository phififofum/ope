class_name RunLog
extends RefCounted

## The structured record of a session, human or bot.
##
## It exists to answer balance questions that cannot be answered by reasoning: is the
## kitchen worth opening, is Act II too long, does anybody ever buy the expensive tool.
## Built alongside the game rather than after it, because retrofitting telemetry means
## discovering you logged the wrong things.
##
## Local only. Nothing leaves the machine without consent — that is a permanent non-goal,
## not a setting.

const LOG_DIRECTORY: String = "user://telemetry"

var session_id: String
var seed_value: int
var profile: String
var player_count: int

var events: Array[Dictionary] = []
var counters: Dictionary = {}
var samples: Array[Dictionary] = []

var _bus: EventBus
var _started_unix: int


func _init(bus: EventBus, p_seed: int, p_profile: String, p_player_count: int) -> void:
	_bus = bus
	seed_value = p_seed
	profile = p_profile
	player_count = p_player_count
	session_id = "%d_%d" % [Time.get_unix_time_from_system(), p_seed]
	_started_unix = Time.get_unix_time_from_system()

	for event_name: String in EventCatalog.names():
		if EventCatalog.kind_of(StringName(event_name)) == EventCatalog.Kind.NOTIFICATION:
			bus.subscribe(
				StringName(event_name),
				func(payload: Dictionary) -> void: record(event_name, payload),
				"telemetry",
				1000
			)


func record(event_name: String, payload: Dictionary) -> void:
	counters[event_name] = int(counters.get(event_name, 0)) + 1
	if events.size() < 20000:
		events.append({"event": event_name, "payload": payload})


## A periodic snapshot of the economy and the loops, so a curve can be plotted rather
## than inferred from totals.
func sample(day: int, tick: int, state: Dictionary) -> void:
	var entry: Dictionary = state.duplicate()
	entry["day"] = day
	entry["tick"] = tick
	samples.append(entry)


func count(event_name: String) -> int:
	return int(counters.get(event_name, 0))


## The balance questions, answered from the log rather than from opinion.
func summary() -> Dictionary:
	var verdicts: Dictionary = {}
	var outcomes: Dictionary = {}
	for entry: Dictionary in events:
		if entry["event"] != String(EventCatalog.VERIFICATION_RESOLVED):
			continue
		var payload: Dictionary = entry["payload"]
		var verdict: String = str(payload.get("verdict", "?"))
		verdicts[verdict] = int(verdicts.get(verdict, 0)) + 1
		var outcome: String = str(payload.get("outcome", -1))
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
	return {
		"session": session_id,
		"seed": seed_value,
		"profile": profile,
		"players": player_count,
		"wall_seconds": Time.get_unix_time_from_system() - _started_unix,
		"counters": counters.duplicate(),
		"verdicts": verdicts,
		"outcomes": outcomes,
		"samples": samples.size(),
	}


func write_to_disk() -> String:
	DirAccess.make_dir_recursive_absolute(LOG_DIRECTORY)
	var path: String = LOG_DIRECTORY.path_join("run_%s.json" % session_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify({"summary": summary(), "samples": samples}, "  "))
	file.close()
	return path
