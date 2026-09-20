class_name SaveSystem
extends RefCounted

## Versioned saves with a forward migration chain.
##
## Two rules govern this file, and both come from the same place — a save is somebody's
## twenty hours:
##
## [b]Never silently drop data.[/b] A save from an older version is migrated, step by
## step, and every step is recorded in the file.
## [b]Never hard-fail.[/b] A save whose mods are missing opens in degraded mode — listed
## plainly, read-only, with the option to strip the affected content — rather than
## refusing to load.

const CURRENT_VERSION: int = 2
const SAVE_DIRECTORY: String = "user://saves"


class LoadResult:
	extends RefCounted
	var ok: bool = false
	var state: Dictionary = {}
	var from_version: int = 0
	var migrations_applied: PackedStringArray = []
	## Mods the save was made with that are not loaded now. Non-empty means degraded.
	var missing_mods: Dictionary = {}
	var degraded: bool = false
	var error: String = ""

	func describe() -> String:
		if not ok:
			return "save could not be read: %s" % error
		var parts: PackedStringArray = ["loaded save v%d" % from_version]
		if not migrations_applied.is_empty():
			parts.append("migrated: %s" % ", ".join(migrations_applied))
		if degraded:
			var names: PackedStringArray = []
			for mod_id: String in missing_mods.keys():
				names.append("%s %s" % [mod_id, missing_mods[mod_id]])
			parts.append("DEGRADED — missing: %s" % ", ".join(names))
		return "; ".join(parts)


static func save_path(slot: String) -> String:
	return SAVE_DIRECTORY.path_join("%s.json" % slot)


## Writes [param state], stamped with the version and the mods that were active. The mod
## list is what makes degraded loading possible later.
static func write(slot: String, state: Dictionary, active_mods: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
	var envelope: Dictionary = {
		"version": CURRENT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"mods": active_mods,
		"state": state,
	}
	var file: FileAccess = FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(envelope, "  "))
	file.close()
	return true


static func read(slot: String, active_mods: Dictionary) -> LoadResult:
	return read_from(save_path(slot), active_mods)


static func read_from(path: String, active_mods: Dictionary) -> LoadResult:
	var result := LoadResult.new()
	if not FileAccess.file_exists(path):
		result.error = "no save at %s" % path
		return result

	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		result.error = (
			"invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		)
		return result
	if not json.data is Dictionary:
		result.error = "save is not an object"
		return result

	var envelope: Dictionary = json.data
	result.from_version = int(envelope.get("version", 1))
	if result.from_version > CURRENT_VERSION:
		result.error = (
			"save is version %d; this build understands up to %d"
			% [result.from_version, CURRENT_VERSION]
		)
		return result

	var state: Dictionary = envelope.get("state", {})
	var version: int = result.from_version
	while version < CURRENT_VERSION:
		var step: String = "%03d_to_%03d" % [version, version + 1]
		state = _migrate(step, state)
		result.migrations_applied.append(step)
		version += 1

	for mod_id: String in (envelope.get("mods", {}) as Dictionary).keys():
		if not active_mods.has(mod_id):
			result.missing_mods[mod_id] = str((envelope.get("mods") as Dictionary)[mod_id])
	result.degraded = not result.missing_mods.is_empty()

	result.state = state
	result.ok = true
	return result


## Removes every definition reference belonging to [param mod_ids]. This is the "strip
## the affected content" option a degraded load offers — destructive, so it is never
## automatic.
static func strip_mod_content(state: Dictionary, mod_ids: PackedStringArray) -> Dictionary:
	var stripped: Dictionary = state.duplicate(true)
	_strip_recursive(stripped, mod_ids)
	return stripped


static func _strip_recursive(value: Variant, mod_ids: PackedStringArray) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key: Variant in dictionary.keys():
			var entry: Variant = dictionary[key]
			if entry is String and _belongs_to(entry, mod_ids):
				dictionary.erase(key)
			else:
				_strip_recursive(entry, mod_ids)
	elif value is Array:
		var array: Array = value
		for index: int in range(array.size() - 1, -1, -1):
			var entry: Variant = array[index]
			if entry is String and _belongs_to(entry, mod_ids):
				array.remove_at(index)
			else:
				_strip_recursive(entry, mod_ids)


static func _belongs_to(id: String, mod_ids: PackedStringArray) -> bool:
	for mod_id: String in mod_ids:
		if id.begins_with(mod_id + ":"):
			return true
	return false


## The migration chain. Each step takes the previous shape and returns the next one.
## Steps are pure functions of the state, so they can be unit-tested without a game.
static func _migrate(step: String, state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	match step:
		"001_to_002":
			# v1 stored a single `cash` float. v2 splits the three currencies apart,
			# because money, reputation and standing stopped being interchangeable.
			if next.has("cash") and not next.has("currencies"):
				next["currencies"] = {
					"money": float(next["cash"]),
					"reputation": float(next.get("reputation", 0.0)),
					"standing": float(next.get("standing", 0.0)),
				}
				next.erase("cash")
				next.erase("reputation")
				next.erase("standing")
	return next
