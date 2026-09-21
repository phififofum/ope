class_name ModApi
extends RefCounted

## What a mod script is handed. Everything a base system can do, a mod can do through
## this — query the registry, subscribe to events, contribute to queries, veto attempts.
##
## Nothing here is a privileged wrapper: base systems use the same registry and the same
## bus. If a base system ever needs something this class cannot express, that is a gap in
## the mod API and it gets fixed rather than worked around.

var mod_id: String
var registry: ContentRegistry
var bus: EventBus

var _log: Array[String] = []


func _init(p_mod_id: String, p_registry: ContentRegistry, p_bus: EventBus) -> void:
	mod_id = p_mod_id
	registry = p_registry
	bus = p_bus


## Subscribe to a notification or query event. The mod id is recorded, so an error or a
## veto can say who was responsible.
func on(event_name: StringName, handler: Callable, priority: int = 0) -> bool:
	return bus.subscribe(event_name, handler, mod_id, priority)


## Subscribe to a cancellable event. Return a non-empty String to veto with that reason,
## or an empty String to allow.
func on_attempt(event_name: StringName, handler: Callable, priority: int = 0) -> bool:
	if EventCatalog.kind_of(event_name) != EventCatalog.Kind.CANCELLABLE:
		log_message("tried to veto '%s', which is not a cancellable event" % event_name)
		return false
	return bus.subscribe(event_name, handler, mod_id, priority)


## Add a definition at runtime, namespaced to this mod. Returns false, with a logged
## reason, rather than raising — a mod must never take the game down.
func define(data: Dictionary) -> bool:
	var id: String = str(data.get("id", ""))
	if not id.begins_with(mod_id + ":"):
		log_message("definition '%s' is not namespaced to this mod" % id)
		return false
	registry.install(ContentDefinition.from_data(data, mod_id))
	return true


func log_message(message: String) -> void:
	_log.append("[%s] %s" % [mod_id, message])


func messages() -> Array[String]:
	return _log.duplicate()
