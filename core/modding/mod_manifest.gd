class_name ModManifest
extends RefCounted

## A content source's identity card. The base game has one of these too, with exactly
## the same shape and no extra fields — that is the whole point.

var id: String = ""
var name: String = ""
var version: String = "0.0.0"
var authors: PackedStringArray = []
var game_api: String = "*"
var dependencies: Dictionary = {}
var load_after: PackedStringArray = []
var load_before: PackedStringArray = []
var load_order: int = 100
var capabilities: PackedStringArray = []
var affects_gameplay: bool = true
var description: String = ""
var directory: String = ""
var errors: PackedStringArray = []


static func from_dictionary(data: Dictionary, directory: String) -> ModManifest:
	var manifest := ModManifest.new()
	manifest.directory = directory
	manifest.id = str(data.get("id", ""))
	manifest.name = str(data.get("name", manifest.id))
	manifest.version = str(data.get("version", "0.0.0"))
	manifest.game_api = str(data.get("game_api", "*"))
	manifest.description = str(data.get("description", ""))
	manifest.load_order = int(data.get("load_order", 100))
	manifest.affects_gameplay = bool(data.get("affects_gameplay", true))
	manifest.dependencies = data.get("dependencies", {})

	for author: String in data.get("authors", []):
		manifest.authors.append(author)
	for other: String in data.get("load_after", []):
		manifest.load_after.append(other)
	for other: String in data.get("load_before", []):
		manifest.load_before.append(other)
	for capability: String in data.get("capabilities", []):
		manifest.capabilities.append(capability)

	if manifest.id.is_empty():
		manifest.errors.append("manifest has no 'id'; definitions cannot be namespaced without one")
	elif not RegEx.create_from_string("^[a-z0-9_.]+$").search(manifest.id):
		manifest.errors.append(
			"mod id '%s' must be lower-case letters, digits, dots or underscores" % manifest.id
		)
	if not Semver.parse(manifest.version).valid:
		manifest.errors.append("version '%s' is not a semantic version" % manifest.version)

	return manifest


func is_valid() -> bool:
	return errors.is_empty()


## Is this mod compatible with the running game's mod API version? An out-of-range mod
## is disabled with a clear message rather than loaded and left to crash.
func supports_api(api_version: String) -> bool:
	return Semver.satisfies(api_version, game_api)


## Cosmetic-only mods may differ between host and client; gameplay mods may not.
func blocks_multiplayer_join() -> bool:
	return affects_gameplay
