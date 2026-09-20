class_name ModLoader
extends RefCounted

## Discovers content sources, resolves their dependencies, and produces a load order
## that is the same on every machine and every run.
##
## Reproducibility is the requirement that shapes this: a topological sort with an
## arbitrary tiebreak would give the host and the client different override winners, and
## the resulting desync would be blamed on the netcode for a week.

const MOD_API_VERSION: String = "0.1.0"


class Resolution:
	extends RefCounted
	## Sources in load order, and everything that went wrong deciding it.
	var order: Array[ModManifest] = []
	var disabled: Dictionary = {}  # mod id -> reason
	var errors: PackedStringArray = []

	func ids() -> PackedStringArray:
		var out: PackedStringArray = []
		for manifest: ModManifest in order:
			out.append(manifest.id)
		return out

	func is_clean() -> bool:
		return errors.is_empty() and disabled.is_empty()


## Reads a manifest from [param directory]. Returns null when there is nothing readable
## there, which is not an error — a folder without a manifest is simply not a mod.
static func read_manifest(directory: String) -> ModManifest:
	var path: String = directory.path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		var broken := ModManifest.new()
		broken.directory = directory
		broken.id = directory.get_file()
		broken.errors.append("manifest.json is not valid JSON")
		return broken
	return ModManifest.from_dictionary(parsed, directory)


## Finds every mod directory under [param mods_root]. Sorted, so discovery order never
## depends on the filesystem.
static func discover(mods_root: String) -> Array[ModManifest]:
	var found: Array[ModManifest] = []
	var dir: DirAccess = DirAccess.open(mods_root)
	if dir == null:
		return found
	var names: PackedStringArray = dir.get_directories()
	names.sort()
	for name: String in names:
		var manifest: ModManifest = read_manifest(mods_root.path_join(name))
		if manifest != null:
			found.append(manifest)
	return found


## Orders [param manifests] so that every mod loads after everything it depends on.
##
## Disabled rather than fatal: a missing dependency, a version mismatch, an invalid
## manifest, or a dependency cycle. Each disables the mods involved and records why, and
## the rest of the game loads. A mod must never take the game down.
static func resolve(
	manifests: Array[ModManifest], api_version: String = MOD_API_VERSION
) -> Resolution:
	var resolution := Resolution.new()
	var usable: Dictionary = {}

	for manifest: ModManifest in manifests:
		if not manifest.is_valid():
			resolution.disabled[manifest.id] = "; ".join(manifest.errors)
			continue
		if usable.has(manifest.id):
			resolution.disabled[manifest.id] = "duplicate mod id"
			continue
		if not manifest.supports_api(api_version):
			resolution.disabled[manifest.id] = (
				"needs game API %s; this build is %s" % [manifest.game_api, api_version]
			)
			continue
		usable[manifest.id] = manifest

	_disable_unsatisfied_dependencies(usable, resolution)
	_order(usable, resolution)
	return resolution


## Dependency failures cascade: if A needs B and B was disabled, A cannot load either.
## Repeat until the set stops shrinking.
static func _disable_unsatisfied_dependencies(usable: Dictionary, resolution: Resolution) -> void:
	var changed: bool = true
	while changed:
		changed = false
		for id: String in usable.keys():
			var manifest: ModManifest = usable[id]
			for dependency_id: String in manifest.dependencies.keys():
				var required_range: String = str(manifest.dependencies[dependency_id])
				if not usable.has(dependency_id):
					resolution.disabled[id] = (
						"requires '%s' %s, which is not loaded" % [dependency_id, required_range]
					)
					usable.erase(id)
					changed = true
					break
				var dependency: ModManifest = usable[dependency_id]
				if not Semver.satisfies(dependency.version, required_range):
					resolution.disabled[id] = (
						"requires '%s' %s, found %s"
						% [dependency_id, required_range, dependency.version]
					)
					usable.erase(id)
					changed = true
					break


static func _order(usable: Dictionary, resolution: Resolution) -> void:
	# Edges point from "must load first" to "loads later".
	var edges: Dictionary = {}
	var incoming: Dictionary = {}
	for id: String in usable.keys():
		edges[id] = []
		incoming[id] = 0

	for id: String in usable.keys():
		var manifest: ModManifest = usable[id]
		for dependency_id: String in manifest.dependencies.keys():
			_add_edge(edges, incoming, dependency_id, id)
		for other: String in manifest.load_after:
			if usable.has(other):
				_add_edge(edges, incoming, other, id)
		for other: String in manifest.load_before:
			if usable.has(other):
				_add_edge(edges, incoming, id, other)

	# Kahn's algorithm, with the ready set kept sorted by declared load order and then
	# by id. That stable tiebreak is what makes the result reproducible run to run.
	var ready: Array[String] = []
	for id: String in usable.keys():
		if int(incoming[id]) == 0:
			ready.append(id)
	_sort_ready(ready, usable)

	while not ready.is_empty():
		var id: String = ready.pop_front()
		resolution.order.append(usable[id])
		for dependent: String in edges[id]:
			incoming[dependent] = int(incoming[dependent]) - 1
			if int(incoming[dependent]) == 0:
				ready.append(dependent)
		_sort_ready(ready, usable)

	if resolution.order.size() < usable.size():
		var cycle: PackedStringArray = []
		for id: String in usable.keys():
			if int(incoming[id]) > 0:
				cycle.append(id)
				resolution.disabled[id] = "part of a dependency cycle"
		cycle.sort()
		resolution.errors.append("dependency cycle between: %s" % ", ".join(cycle))


static func _add_edge(
	edges: Dictionary, incoming: Dictionary, from_id: String, to_id: String
) -> void:
	if not edges.has(from_id) or not incoming.has(to_id):
		return
	var list: Array = edges[from_id]
	if list.has(to_id):
		return
	list.append(to_id)
	edges[from_id] = list
	incoming[to_id] = int(incoming[to_id]) + 1


static func _sort_ready(ready: Array[String], usable: Dictionary) -> void:
	ready.sort_custom(
		func(a: String, b: String) -> bool:
			var left: ModManifest = usable[a]
			var right: ModManifest = usable[b]
			if left.load_order != right.load_order:
				return left.load_order < right.load_order
			return a < b
	)
