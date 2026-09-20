class_name ContentRegistry
extends RefCounted

## The typed, queryable store every definition lands in at boot.
##
## The rule that makes the whole architecture work: [b]no system ever names a specific
## content id in code.[/b] Systems ask for "every product tagged chilled and
## age_restricted" and get correct behaviour for content that did not exist when they
## were written — including content a mod adds at load time.

var _by_id: Dictionary = {}
var _by_type: Dictionary = {}
var _overrides: Array[Dictionary] = []


## Installs a definition. A second definition with the same id overrides the first and
## the override is recorded, because "which mod won" is a question players ask.
func install(definition: ContentDefinition) -> void:
	if _by_id.has(definition.id):
		var previous: ContentDefinition = _by_id[definition.id]
		(
			_overrides
			. append(
				{
					"id": String(definition.id),
					"overridden_source": previous.source_id,
					"winning_source": definition.source_id,
				}
			)
		)
		var previous_list: Array = _by_type.get(previous.type, [])
		previous_list.erase(previous)
		_by_type[previous.type] = previous_list
	_by_id[definition.id] = definition
	var list: Array = _by_type.get(definition.type, [])
	list.append(definition)
	list.sort_custom(
		func(a: ContentDefinition, b: ContentDefinition) -> bool: return String(a.id) < String(b.id)
	)
	_by_type[definition.type] = list


func has(id: StringName) -> bool:
	return _by_id.has(id)


func get_definition(id: StringName) -> ContentDefinition:
	return _by_id.get(id, null)


## Every definition of a type, sorted by id so that iteration order is deterministic —
## which matters, because a spawn table walked in a different order is a different game.
func by_type(type: StringName) -> Array:
	return (_by_type.get(type, []) as Array).duplicate()


## Every definition of a type carrying all of [param tags]. This is the workhorse:
## "every product that is chilled and age_restricted" is one call and no hardcoded ids.
func by_tags(type: StringName, tags: PackedStringArray) -> Array:
	var out: Array = []
	for definition: ContentDefinition in by_type(type):
		if definition.has_all_tags(tags):
			out.append(definition)
	return out


## Definitions of a type where [param key] equals [param value]. Used for field lookups
## that are not tags — a document family, a licence, a station.
func by_field(type: StringName, key: String, value: Variant) -> Array:
	var out: Array = []
	for definition: ContentDefinition in by_type(type):
		if definition.get_value(key) == value:
			out.append(definition)
	return out


func types() -> Array:
	var names: Array[String] = []
	for type: StringName in _by_type.keys():
		if not (_by_type[type] as Array).is_empty():
			names.append(String(type))
	names.sort()
	var out: Array = []
	for name: String in names:
		out.append(StringName(name))
	return out


func count_of(type: StringName) -> int:
	return (_by_type.get(type, []) as Array).size()


func size() -> int:
	return _by_id.size()


func overrides() -> Array[Dictionary]:
	return _overrides.duplicate()


func ids_from_source(source_id: String) -> Array:
	var names: Array[String] = []
	for id: StringName in _by_id.keys():
		var definition: ContentDefinition = _by_id[id]
		if definition.source_id == source_id:
			names.append(String(id))
	names.sort()
	var out: Array = []
	for name: String in names:
		out.append(StringName(name))
	return out


## Removes everything a source provided. This is how a mod that failed at runtime is
## disabled without restarting.
func remove_source(source_id: String) -> int:
	var removed: int = 0
	for id: StringName in ids_from_source(source_id):
		var definition: ContentDefinition = _by_id[id]
		var list: Array = _by_type.get(definition.type, [])
		list.erase(definition)
		_by_type[definition.type] = list
		_by_id.erase(id)
		removed += 1
	return removed


func clear() -> void:
	_by_id.clear()
	_by_type.clear()
	_overrides.clear()
