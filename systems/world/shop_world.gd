class_name ShopWorld
extends Node3D

## Builds the room from fixture definitions and keeps it in step with the simulation.
##
## The geometry is placeholder -- boxes with materials, pending the art pass -- but the
## layout is not: fixtures come from data, zones carry noise, and the counter's sightline
## is computed from where things actually are. A retexture changes how this looks. It
## does not change how it plays.

signal built(fixture_count: int)
signal customer_arrived(encounter_id: int)

const ROOM_SIZE := Vector3(16.0, 3.2, 12.0)
const TILE: float = 1.0

var shop: Shop
var player: PlayerController

var fixtures: Array[Node3D] = []
var interactables: Array[Interactable] = []
var counter_position := Vector3(0.0, 0.0, -3.0)

var _materials: Dictionary = {}
var _customers: Array[MeshInstance3D] = []


func build(p_shop: Shop) -> void:
	shop = p_shop
	_build_room()
	_place_fixtures()
	_place_player()
	built.emit(fixtures.size())


func _build_room() -> void:
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(ROOM_SIZE.x, 0.2, ROOM_SIZE.z)
	floor_mesh.mesh = floor_box
	floor_mesh.material_override = _material("floor", Color(0.22, 0.2, 0.19))
	floor_mesh.position = Vector3(0.0, -0.1, 0.0)
	add_child(floor_mesh)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = floor_box.size
	shape.shape = box
	body.add_child(shape)
	body.position = floor_mesh.position
	add_child(body)

	# A ceiling, because a room without one reads as a corridor and the light has nothing
	# to bounce off.
	_add_box(
		Vector3(0.0, ROOM_SIZE.y, 0.0),
		Vector3(ROOM_SIZE.x, 0.2, ROOM_SIZE.z),
		_material("ceiling", Color(0.26, 0.25, 0.26)),
		false
	)

	for wall: Array in [
		[
			Vector3(0.0, ROOM_SIZE.y * 0.5, -ROOM_SIZE.z * 0.5),
			Vector3(ROOM_SIZE.x, ROOM_SIZE.y, 0.2)
		],
		[
			Vector3(0.0, ROOM_SIZE.y * 0.5, ROOM_SIZE.z * 0.5),
			Vector3(ROOM_SIZE.x, ROOM_SIZE.y, 0.2)
		],
		[
			Vector3(-ROOM_SIZE.x * 0.5, ROOM_SIZE.y * 0.5, 0.0),
			Vector3(0.2, ROOM_SIZE.y, ROOM_SIZE.z)
		],
		[
			Vector3(ROOM_SIZE.x * 0.5, ROOM_SIZE.y * 0.5, 0.0),
			Vector3(0.2, ROOM_SIZE.y, ROOM_SIZE.z)
		],
	]:
		_add_box(wall[0], wall[1], _material("wall", Color(0.3, 0.29, 0.31)), true)

	# Warm, over-lit fluorescents against a dark street. The light does as much of the
	# work as the geometry here, so it gets an environment rather than one bright bulb:
	# ambient fill to keep the room readable, tonemapping so the whites are not blown.
	var environment := WorldEnvironment.new()
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color(0.05, 0.05, 0.07)
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color(0.55, 0.52, 0.5)
	world_environment.ambient_light_energy = 0.9
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.tonemap_white = 3.0
	environment.environment = world_environment
	add_child(environment)

	# Strip lights down the room, the way a long narrow space is actually lit.
	for offset: float in [-4.0, 0.0, 4.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(offset, 2.85, 0.0)
		light.light_color = Color(1.0, 0.95, 0.86)
		light.light_energy = 0.9
		light.omni_range = 9.0
		light.omni_attenuation = 1.4
		add_child(light)


## Places one fixture per definition, laid out along the zones the definitions declare.
## A mod that adds a fixture gets a place in the room without touching this file.
func _place_fixtures() -> void:
	var zone_cursor: Dictionary = {}
	var zone_origin: Dictionary = {
		"counter": Vector3(-4.0, 0.0, -3.0),
		"kitchen": Vector3(4.0, 0.0, -3.5),
		"library": Vector3(-6.5, 0.0, 2.0),
		"play": Vector3(0.0, 0.0, 3.0),
		"service": Vector3(6.0, 0.0, 0.0),
		"back": Vector3(6.5, 0.0, 4.5),
		"any": Vector3(0.0, 0.0, 0.0),
	}

	var placed: int = 0
	for fixture: ContentDefinition in shop.registry.by_type(&"fixture"):
		if placed >= 28:
			break  # the starting room, not the whole catalogue
		var zone: String = fixture.get_text("zone", "any")
		var index: int = int(zone_cursor.get(zone, 0))
		zone_cursor[zone] = index + 1
		var origin: Vector3 = zone_origin.get(zone, Vector3.ZERO)
		var offset := Vector3(float(index % 4) * 1.6, 0.0, floor(float(index) / 4.0) * 1.6)
		var footprint: Array = fixture.get_value("footprint", [1, 1])
		var size := Vector3(float(footprint[0]) * 0.9, 0.9, float(footprint[1]) * 0.9)
		var node: Node3D = _add_box(
			origin + offset + Vector3(0.0, size.y * 0.5, 0.0),
			size,
			_material(fixture.get_text("category"), _category_colour(fixture.get_text("category"))),
			true
		)
		node.name = String(fixture.id).replace(":", "_")
		fixtures.append(node)
		_attach_interactable(node, fixture, size)
		placed += 1


func _attach_interactable(node: Node3D, fixture: ContentDefinition, size: Vector3) -> void:
	var interactable := Interactable.new()
	match fixture.get_text("category"):
		"counter":
			interactable.kind = Interactable.Kind.COUNTER
			interactable.prompt = "Serve"
			interactable.seconds = 4.0
			counter_position = node.position
		"kitchen":
			interactable.kind = Interactable.Kind.KITCHEN_STATION
			interactable.prompt = (
				"Work the %s" % fixture.get_text("name").replace("loc:fixture.", "")
			)
			interactable.seconds = 6.0
			interactable.station_name = fixture.get_text("name")
		"shelf":
			interactable.kind = (
				Interactable.Kind.LIBRARY_SHELF
				if fixture.get_text("zone") == "library"
				else Interactable.Kind.RETAIL_SHELF
			)
			interactable.prompt = "Shelve"
			interactable.seconds = 12.0
		"case":
			interactable.kind = Interactable.Kind.CASE
			interactable.prompt = "Work the case"
			interactable.seconds = 25.0
		"table":
			interactable.kind = Interactable.Kind.TABLE
			interactable.prompt = "Reset the table"
			interactable.seconds = 20.0
		_:
			interactable.kind = Interactable.Kind.BIN
			interactable.prompt = "Tidy"
			interactable.seconds = 15.0
	interactable.position = node.position + Vector3(0.0, size.y * 0.5, 0.0)
	interactable.scale = size
	add_child(interactable)
	interactables.append(interactable)


## Placeholder figures until the character pass: a body at the counter is the difference
## between a room and a diagram, and the queue has to be visible from anywhere in the shop.
func sync_customers() -> void:
	var wanted: int = shop.waiting_encounters.size() if shop != null else 0
	while _customers.size() < wanted:
		var index: int = _customers.size()
		var figure := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.75
		capsule.radius = 0.3
		figure.mesh = capsule
		figure.material_override = _material(
			"person_%d" % (index % 4), Color(0.45 + 0.1 * float(index % 3), 0.4, 0.38)
		)
		figure.position = counter_position + Vector3(0.0, 0.95, 1.4 + float(index) * 0.75)
		add_child(figure)
		_customers.append(figure)
	while _customers.size() > wanted:
		var last: MeshInstance3D = _customers.pop_back()
		last.queue_free()


func _place_player() -> void:
	player = PlayerController.new()
	# Facing the counter, because that is what the player is here to do.
	player.position = counter_position + Vector3(1.2, 0.1, 5.4)
	# A camera looks down -Z by default, and the counter is at -Z from the door: the
	# player starts looking at the thing they are here to do.
	player.rotation.y = 0.0
	add_child(player)


## How much of the room the counter can see. What you cannot watch is shrink exposure,
## and singles are the highest-value goods in the building.
func counter_sightline() -> float:
	var watched: int = 0
	var total: int = 0
	for interactable: Interactable in interactables:
		if interactable.kind not in [Interactable.Kind.CASE, Interactable.Kind.RETAIL_SHELF]:
			continue
		total += 1
		if interactable.position.distance_to(counter_position) < 6.0:
			watched += 1
	return 1.0 if total == 0 else clampf(float(watched) / float(total), 0.15, 0.95)


## Noise as a simulated field rather than a per-zone flag: a tournament twelve feet from
## a two-player game ruins both, and shelving in between is what saves them.
func noise_at(point: Vector3) -> float:
	var level: float = 0.0
	for fixture: Node3D in fixtures:
		var definition_id: String = fixture.name.replace("_", ":")
		var definition: ContentDefinition = shop.registry.get_definition(StringName(definition_id))
		if definition == null:
			continue
		var emission: float = definition.get_number("noise", 0.0)
		var distance: float = maxf(0.6, fixture.position.distance_to(point))
		level += emission / (distance * distance)
	return clampf(level, 0.0, 1.0)


func _add_box(centre: Vector3, size: Vector3, material: Material, solid: bool) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = centre
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		body.add_child(shape)
		body.position = centre
		add_child(body)
	return mesh


func _material(key: String, colour: Color) -> Material:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	_materials[key] = material
	return material


func _category_colour(category: String) -> Color:
	match category:
		"table":
			return Color(0.42, 0.3, 0.2)
		"shelf":
			return Color(0.36, 0.28, 0.22)
		"case":
			return Color(0.2, 0.28, 0.34)
		"kitchen":
			return Color(0.5, 0.5, 0.54)
		"counter":
			return Color(0.34, 0.26, 0.2)
		"cooler":
			return Color(0.24, 0.34, 0.38)
		_:
			return Color(0.3, 0.3, 0.32)
