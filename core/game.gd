extends Node

## The one autoload: everything long-lived, in one place, so systems can find each other
## without knowing about each other.
##
## It owns the registry, the bus, the clock and the RNG, and nothing else. Gameplay lives
## in systems/, which read the registry and talk through the bus. If this file starts
## growing gameplay logic, something has gone wrong.

signal content_loaded(report: ContentLoader.LoadReport)
signal boot_failed(reason: String)

const MOD_API_VERSION: String = ModLoader.MOD_API_VERSION

var registry := ContentRegistry.new()
var bus := EventBus.new()
var clock := TickScheduler.new()
var rng := SeededRng.new(0)
var mods := ModRuntime.new()

var load_report: ContentLoader.LoadReport
var active_mods: Dictionary = {}

var _loaded: bool = false


func _ready() -> void:
	# Systems are ticked explicitly by whoever owns them, not by the autoload: a headless
	# test drives the clock directly, and the bot player drives it faster than real time.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Loads all content. Safe to call more than once; later calls reload from disk, which is
## what hot reload does.
func boot(
	session_seed: int = 0, mods_path: String = ContentLoader.MODS_PATH
) -> ContentLoader.LoadReport:
	registry.clear()
	bus.clear_errors()
	rng = SeededRng.new(session_seed)

	var loader := ContentLoader.new(registry)
	load_report = loader.load_all(ContentLoader.BASE_CONTENT_PATH, mods_path)

	var resolution: ModLoader.Resolution = ModLoader.resolve(ModLoader.discover(mods_path))
	active_mods = {"base": "0.1.0"}
	for manifest: ModManifest in resolution.order:
		active_mods[manifest.id] = manifest.version
	mods.activate_all(resolution.order, registry, bus)

	_loaded = true
	content_loaded.emit(load_report)
	if not load_report.errors().is_empty():
		boot_failed.emit(load_report.summary())
	return load_report


func is_loaded() -> bool:
	return _loaded


## A one-line status for the boot screen, the telemetry log and the handoff report.
func status_line() -> String:
	if load_report == null:
		return "not booted"
	return (
		"%d definitions, %d source(s), %d error(s)"
		% [
			registry.size(),
			load_report.sources.size(),
			load_report.errors().size(),
		]
	)
