class_name ModRuntime
extends RefCounted

## Runs mod scripts, guarded.
##
## A mod script is [code]scripts/main.gd[/code] with a [code]_enter_mod(api: ModApi)[/code]
## function. Every failure mode — no script, unloadable script, wrong shape, an error on
## entry — disables that mod and records why. The game continues without it, because the
## alternative is a player whose game will not start because of somebody else's typo.


class ActiveMod:
	extends RefCounted
	var manifest: ModManifest
	var api: ModApi
	var instance: Object


var _active: Dictionary = {}
var _failures: Dictionary = {}


func active_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for id: String in _active.keys():
		ids.append(id)
	ids.sort()
	return ids


func failures() -> Dictionary:
	return _failures.duplicate()


func api_for(mod_id: String) -> ModApi:
	var entry: ActiveMod = _active.get(mod_id, null)
	return entry.api if entry != null else null


## Activates every mod that has a script. Mods without one are data-only and need
## nothing here.
func activate_all(manifests: Array[ModManifest], registry: ContentRegistry, bus: EventBus) -> void:
	for manifest: ModManifest in manifests:
		activate(manifest, registry, bus)


func activate(manifest: ModManifest, registry: ContentRegistry, bus: EventBus) -> bool:
	var script_path: String = manifest.directory.path_join("scripts/main.gd")
	if not FileAccess.file_exists(script_path):
		return false

	var script: Resource = load(script_path)
	if script == null or not script is GDScript:
		_fail(manifest, "scripts/main.gd could not be loaded as a GDScript")
		return false

	var instance: Object = (script as GDScript).new()
	if instance == null:
		_fail(manifest, "scripts/main.gd did not produce an object")
		return false
	if not instance.has_method("_enter_mod"):
		_fail(manifest, "scripts/main.gd has no _enter_mod(api) function")
		return false

	var api := ModApi.new(manifest.id, registry, bus)
	instance.call("_enter_mod", api)

	var entry := ActiveMod.new()
	entry.manifest = manifest
	entry.api = api
	entry.instance = instance
	_active[manifest.id] = entry
	return true


## Disables a mod: its event subscriptions are dropped and its content is removed. This
## is what the mod-error screen's "disable and continue" does.
func deactivate(mod_id: String, registry: ContentRegistry, bus: EventBus, reason: String) -> void:
	bus.unsubscribe_owner(mod_id)
	registry.remove_source(mod_id)
	_active.erase(mod_id)
	_failures[mod_id] = reason


func _fail(manifest: ModManifest, reason: String) -> void:
	_failures[manifest.id] = reason
