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
var _customers: Array[Node3D] = []


func build(p_shop: Shop) -> void:
	shop = p_shop
	_build_room()
	_place_fixtures()
	_place_player()
	built.emit(fixtures.size())


## The shell: floor, walls, ceiling, the window onto the street, and the light.
##
## Everything here is generated -- see [Surfaces] -- so the room has grain, tile and
## paintwork without a single imported image.
func _build_room() -> void:
	var boards: Texture2D = Surfaces.tile(Color(0.31, 0.29, 0.27), Color(0.19, 0.18, 0.18))
	var floor_material: StandardMaterial3D = Surfaces.textured(
		boards, Vector3(ROOM_SIZE.x * 0.25, ROOM_SIZE.z * 0.25, 1.0), 0.75
	)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(ROOM_SIZE.x, 0.2, ROOM_SIZE.z)
	floor_mesh.mesh = floor_box
	floor_mesh.material_override = floor_material
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
		Surfaces.matte(Color(0.42, 0.41, 0.4), 0.98),
		false
	)

	var paint: StandardMaterial3D = Surfaces.textured(
		Surfaces.plaster(Color(0.5, 0.45, 0.39)), Vector3(4.0, 1.0, 1.0), 0.95
	)
	var panelling: StandardMaterial3D = Surfaces.textured(
		Surfaces.wood(Color(0.34, 0.22, 0.15)), Vector3(8.0, 1.0, 1.0), 0.7
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
		_add_box(wall[0], wall[1], paint, true)
		# Wainscot: a dado rail's worth of timber round the bottom of the room, which is
		# most of what stops a flat wall reading as a flat wall.
		var low: Vector3 = wall[0]
		low.y = 0.5
		var thickness: Vector3 = wall[1]
		thickness.y = 1.0
		_add_box(
			low + _toward_room(low) * 0.11, thickness * Vector3(0.999, 1.0, 0.999), panelling, false
		)

	_build_window()
	_build_lighting()


## The street outside, seen through the front glass. It is a lit panel rather than a
## world, but it gives the room an outside to be inside of -- and at this hour the point
## is that it is dark out there and warm in here.
func _build_window() -> void:
	var z: float = ROOM_SIZE.z * 0.5 - 0.14
	_add_box(
		Vector3(-2.5, 1.85, z),
		Vector3(5.6, 2.1, 0.06),
		Surfaces.glowing(Color(0.1, 0.13, 0.22), 0.3),
		false
	)
	var frame: StandardMaterial3D = Surfaces.textured(
		Surfaces.wood(Color(0.3, 0.19, 0.13)), Vector3(3.0, 1.0, 1.0), 0.6
	)
	for bar: Array in [
		[Vector3(-2.5, 0.78, z), Vector3(5.8, 0.12, 0.12)],
		[Vector3(-2.5, 2.92, z), Vector3(5.8, 0.12, 0.12)],
		[Vector3(-5.35, 1.85, z), Vector3(0.12, 2.2, 0.12)],
		[Vector3(0.35, 1.85, z), Vector3(0.12, 2.2, 0.12)],
		[Vector3(-2.5, 1.85, z), Vector3(0.08, 2.1, 0.1)],
	]:
		_add_box(bar[0], bar[1], frame, false)

	# The sign in the window, lit from behind, facing the street.
	_add_box(
		Vector3(-2.5, 2.45, z - 0.1),
		Vector3(2.4, 0.5, 0.06),
		Surfaces.glowing(Color(0.95, 0.42, 0.28), 1.3),
		false
	)

	# Streetlight leaking in, cold against the warm interior.
	var outside := OmniLight3D.new()
	outside.position = Vector3(-2.5, 2.1, z - 0.8)
	outside.light_color = Color(0.55, 0.68, 0.95)
	outside.light_energy = 0.7
	outside.omni_range = 7.0
	add_child(outside)


## Warm, over-lit fluorescents against a dark street. The light does as much of the work
## as the geometry, so it gets an environment rather than one bright bulb.
func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color(0.04, 0.04, 0.06)
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color(0.42, 0.44, 0.52)
	world_environment.ambient_light_energy = 0.2
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.tonemap_white = 6.0
	world_environment.tonemap_exposure = 0.5
	world_environment.ssao_enabled = true
	world_environment.ssao_radius = 0.9
	world_environment.ssao_intensity = 1.6
	# The glow is what makes the case, the sign and the strip lights read as light
	# sources rather than as pale paint.
	world_environment.glow_enabled = true
	world_environment.glow_intensity = 0.28
	world_environment.glow_bloom = 0.12
	environment.environment = world_environment
	add_child(environment)

	for offset: float in [-5.0, -1.5, 2.0, 5.5]:
		# The fitting, then the light it casts. A bare OmniLight3D with nothing to come
		# out of is the single most placeholder-looking thing in a room.
		_add_box(
			Vector3(offset, ROOM_SIZE.y - 0.16, 0.0),
			Vector3(0.3, 0.08, 4.5),
			Surfaces.glowing(Color(1.0, 0.96, 0.88), 0.55),
			false
		)
		for along: float in [-0.5]:
			var light := OmniLight3D.new()
			light.position = Vector3(offset, 2.8, along)
			light.light_color = Color(1.0, 0.94, 0.84)
			light.light_energy = 0.75
			light.omni_range = 5.2
			light.omni_attenuation = 1.2
			light.shadow_enabled = offset < 0.0
			add_child(light)


## Which way is into the room from a wall at [param point] -- used to sit the panelling
## just proud of the plaster.
func _toward_room(point: Vector3) -> Vector3:
	return Vector3(-signf(point.x), 0.0, -signf(point.z))


## Places one fixture per definition, laid out along the zones the definitions declare.
## A mod that adds a fixture gets a place in the room without touching this file.
func _place_fixtures() -> void:
	var zone_cursor: Dictionary = {}
	# Where each zone starts, and which way it runs from there. A shop is walls with
	# things against them and a floor you walk down the middle of -- laying fixtures out
	# in a grid in the open floor is what made this read as a warehouse.
	var zone_origin: Dictionary = {
		"counter": Vector3(-6.2, 0.0, -4.4),
		"kitchen": Vector3(2.4, 0.0, -4.6),
		"library": Vector3(-7.2, 0.0, 0.4),
		"play": Vector3(-3.4, 0.0, 3.4),
		"service": Vector3(6.9, 0.0, -1.5),
		"back": Vector3(6.6, 0.0, 4.4),
		"any": Vector3(2.0, 0.0, 1.6),
	}
	var zone_run: Dictionary = {
		"counter": Vector3(1.9, 0.0, 0.0),
		"kitchen": Vector3(1.9, 0.0, 0.0),
		"library": Vector3(0.0, 0.0, 1.7),
		"play": Vector3(2.4, 0.0, 0.0),
		"service": Vector3(0.0, 0.0, 1.8),
		"back": Vector3(-1.8, 0.0, 0.0),
		"any": Vector3(1.8, 0.0, 0.0),
	}

	var placed: int = 0
	for fixture: ContentDefinition in _room_furniture():
		if placed >= 28:
			break  # the starting room, not the whole catalogue
		var zone: String = fixture.get_text("zone", "any")
		var index: int = int(zone_cursor.get(zone, 0))
		zone_cursor[zone] = index + 1
		var origin: Vector3 = zone_origin.get(zone, Vector3.ZERO)
		var run: Vector3 = zone_run.get(zone, Vector3(1.8, 0.0, 0.0))
		# Wrap onto a second row rather than walking a shelf through the wall.
		var along: int = index % 4
		var row: int = int(floor(float(index) / 4.0))
		var offset: Vector3 = (
			run * float(along) + Vector3(run.z, 0.0, run.x).normalized() * float(row) * 1.5
		)
		var footprint: Array = fixture.get_value("footprint", [1, 1])
		var size := Vector3(float(footprint[0]) * 0.9, 0.9, float(footprint[1]) * 0.9)
		var node: Node3D = _build_fixture(fixture, origin + offset, size)
		fixtures.append(node)
		_attach_interactable(node, fixture, size)
		placed += 1


## What goes in the room, in the order it matters. A shop with no back door and no rack of
## packs is missing verbs, so one of each category and everything the loops are played on
## is placed before the catalogue is allowed to fill the remaining space.
##
## The rule is still data-driven: a mod's fixture gets a place here without touching this
## file, and a mod's pack rack is a pack rack because of its tags.
func _room_furniture() -> Array:
	var essential: Array = []
	var rest: Array = []
	var categories_seen: Dictionary = {}
	for fixture: ContentDefinition in shop.registry.by_type(&"fixture"):
		var tags: Array = fixture.get_value("tags", [])
		var category: String = fixture.get_text("category")
		var first_of_category: bool = not categories_seen.has(category)
		categories_seen[category] = true
		if first_of_category or tags.has("back_door") or tags.has("sealed") or tags.has("display"):
			essential.append(fixture)
		else:
			rest.append(fixture)
	return essential + rest


## Builds the fixture itself, in parts, according to what it is for.
##
## A shelf is uprights and boards with stock on them; a case is a lit box under glass
## with cards in it; a table has legs. One box per fixture was what made the room read as
## a diagram of a shop rather than a shop.
func _build_fixture(fixture: ContentDefinition, centre: Vector3, size: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = centre
	root.name = String(fixture.id).replace(":", "_")
	add_child(root)

	var tags: Array = fixture.get_value("tags", [])
	match fixture.get_text("category"):
		"shelf":
			_build_shelving(root, size, tags.has("sealed"))
		"case":
			_build_display_case(root, size)
		"counter":
			_build_counter(root, size)
		"table":
			_build_table(root, size)
		"kitchen":
			_build_kitchen_station(root, size)
		"cooler":
			_build_cooler(root, size)
		_:
			_attach(root, Vector3(0.0, size.y * 0.5, 0.0), size, _carcass())

	# One collider for the whole fixture: the parts are decoration, the footprint is what
	# the player walks into.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = Vector3(size.x, maxf(size.y, 1.0), size.z)
	shape.shape = collision
	body.add_child(shape)
	body.position = Vector3(0.0, collision.size.y * 0.5, 0.0)
	root.add_child(body)
	return root


## Uprights, boards, and product on the boards. The stock is coloured by category, so a
## wall of sealed product looks different from a wall of crisps at a glance -- which is
## the whole job of a shop shelf.
func _build_shelving(root: Node3D, size: Vector3, sealed: bool) -> void:
	var height: float = 2.1
	var carcass: StandardMaterial3D = _carcass()
	_attach(root, Vector3(-size.x * 0.5, height * 0.5, 0.0), Vector3(0.08, height, size.z), carcass)
	_attach(root, Vector3(size.x * 0.5, height * 0.5, 0.0), Vector3(0.08, height, size.z), carcass)
	_attach(root, Vector3(0.0, height, 0.0), Vector3(size.x, 0.08, size.z), carcass)
	_attach(root, Vector3(0.0, 0.06, 0.0), Vector3(size.x, 0.12, size.z), carcass)

	var shelf_count: int = 4
	for level: int in range(shelf_count):
		var y: float = 0.38 + float(level) * 0.44
		_attach(root, Vector3(0.0, y, 0.0), Vector3(size.x - 0.1, 0.05, size.z * 0.9), carcass)
		# A strip light under each board. Retail lighting is mostly this.
		_attach(
			root,
			Vector3(0.0, y + 0.4, -size.z * 0.28),
			Vector3(size.x - 0.24, 0.03, 0.05),
			Surfaces.glowing(Color(1.0, 0.97, 0.9), 0.3)
		)
		_stock_a_shelf(root, size, y, level, sealed)


## The goods. Deterministic from the level index so a shelf does not reshuffle itself
## every time the room is built, which would make the visual baseline meaningless.
func _stock_a_shelf(root: Node3D, size: Vector3, y: float, level: int, sealed: bool) -> void:
	var palette: Array = (
		[Color(0.85, 0.33, 0.26), Color(0.93, 0.74, 0.22), Color(0.24, 0.44, 0.72)]
		if sealed
		else [Color(0.42, 0.55, 0.36), Color(0.76, 0.6, 0.35), Color(0.6, 0.38, 0.55)]
	)
	var across: int = maxi(3, int(size.x / 0.22))
	for index: int in range(across):
		# A gap or two, because a perfectly faced shelf is a rendering, not a shop.
		if (index * 7 + level * 3) % 11 == 0:
			continue
		var width: float = size.x / float(across)
		var x: float = -size.x * 0.5 + width * (float(index) + 0.5)
		var tint: Color = palette[(index + level) % palette.size()]
		var tall: float = 0.2 + 0.08 * float((index + level) % 3)
		_attach(
			root,
			Vector3(x, y + 0.03 + tall * 0.5, 0.0),
			Vector3(width * 0.78, tall, size.z * 0.55),
			Surfaces.matte(tint, 0.8)
		)


## The case: a lit box you look down into, with cards standing up in it. This is the
## thing the game is named after being able to look at.
func _build_display_case(root: Node3D, size: Vector3) -> void:
	var carcass: StandardMaterial3D = _carcass()
	_attach(root, Vector3(0.0, 0.42, 0.0), Vector3(size.x, 0.84, size.z), carcass)
	_attach(
		root,
		Vector3(0.0, 0.86, 0.0),
		Vector3(size.x, 0.04, size.z),
		Surfaces.metal(Color(0.46, 0.47, 0.5), 0.6)
	)
	# The interior, lit from inside so the glass has something to glow with.
	_attach(
		root,
		Vector3(0.0, 0.9, 0.0),
		Vector3(size.x - 0.1, 0.02, size.z - 0.1),
		Surfaces.glowing(Color(1.0, 0.97, 0.9), 0.08)
	)
	for index: int in range(maxi(4, int(size.x / 0.3))):
		var step: float = size.x / float(maxi(4, int(size.x / 0.3)))
		var x: float = -size.x * 0.5 + step * (float(index) + 0.5)
		var rare: bool = index % 4 == 2
		_attach(
			root,
			Vector3(x, 1.02, 0.02 * float(index % 3)),
			Vector3(step * 0.6, 0.24, 0.015),
			Surfaces.matte(Color(0.86, 0.72, 0.32) if rare else Color(0.72, 0.76, 0.84), 0.45)
		)
	# The glass goes on last so it draws over what is inside it.
	_attach(
		root,
		Vector3(0.0, 1.12, 0.0),
		Vector3(size.x, 0.44, size.z),
		Surfaces.glass(Color(0.5, 0.62, 0.66, 0.13))
	)
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.0, 0.0)
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 0.5
	light.omni_range = 2.2
	root.add_child(light)


## Where the player stands: a solid front, a worn top, and a till.
func _build_counter(root: Node3D, size: Vector3) -> void:
	_attach(root, Vector3(0.0, 0.46, 0.0), Vector3(size.x, 0.92, size.z), _carcass())
	_attach(
		root,
		Vector3(0.0, 0.95, 0.0),
		Vector3(size.x + 0.08, 0.06, size.z + 0.08),
		Surfaces.textured(Surfaces.wood(Color(0.45, 0.31, 0.2)), Vector3(2.0, 1.0, 1.0), 0.45)
	)
	_attach(
		root,
		Vector3(size.x * 0.28, 1.1, 0.0),
		Vector3(0.34, 0.24, 0.3),
		Surfaces.matte(Color(0.2, 0.21, 0.23), 0.5)
	)
	_attach(
		root,
		Vector3(size.x * 0.28, 1.23, -0.04),
		Vector3(0.26, 0.12, 0.02),
		Surfaces.glowing(Color(0.4, 0.95, 0.6), 1.2)
	)


func _build_table(root: Node3D, size: Vector3) -> void:
	var timber: StandardMaterial3D = Surfaces.textured(
		Surfaces.wood(Color(0.42, 0.29, 0.19)), Vector3(2.0, 2.0, 1.0), 0.6
	)
	_attach(root, Vector3(0.0, 0.74, 0.0), Vector3(size.x, 0.06, size.z), timber)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_attach(
			root,
			Vector3(corner.x * (size.x * 0.5 - 0.08), 0.37, corner.y * (size.z * 0.5 - 0.08)),
			Vector3(0.07, 0.74, 0.07),
			timber
		)
		# A stool per corner: an empty table reads as furniture, an occupied one as a cafe.
		_attach(
			root,
			Vector3(corner.x * (size.x * 0.5 + 0.34), 0.44, corner.y * (size.z * 0.5 + 0.12)),
			Vector3(0.34, 0.08, 0.34),
			Surfaces.textured(Surfaces.fabric(Color(0.55, 0.28, 0.3)), Vector3.ONE, 0.95)
		)


func _build_kitchen_station(root: Node3D, size: Vector3) -> void:
	_attach(
		root,
		Vector3(0.0, 0.45, 0.0),
		Vector3(size.x, 0.9, size.z),
		Surfaces.metal(Color(0.4, 0.42, 0.45), 0.62)
	)
	_attach(
		root,
		Vector3(0.0, 0.93, 0.0),
		Vector3(size.x, 0.05, size.z),
		Surfaces.metal(Color(0.5, 0.52, 0.55), 0.5)
	)
	for ring: float in [-0.22, 0.22]:
		_attach(
			root,
			Vector3(ring, 0.97, 0.0),
			Vector3(0.24, 0.02, 0.24),
			Surfaces.glowing(Color(0.95, 0.35, 0.18), 1.5)
		)
	# The extractor hood, which is most of what makes a kitchen look like a kitchen.
	_attach(
		root,
		Vector3(0.0, 1.85, -size.z * 0.2),
		Vector3(size.x + 0.2, 0.3, size.z * 0.9),
		Surfaces.metal(Color(0.44, 0.46, 0.48), 0.55)
	)


func _build_cooler(root: Node3D, size: Vector3) -> void:
	_attach(
		root,
		Vector3(0.0, 0.9, 0.0),
		Vector3(size.x, 1.8, size.z),
		Surfaces.metal(Color(0.26, 0.28, 0.32), 0.65)
	)
	for level: int in range(3):
		var y: float = 0.5 + float(level) * 0.45
		_attach(
			root,
			Vector3(0.0, y, size.z * 0.1),
			Vector3(size.x - 0.16, 0.34, size.z * 0.5),
			Surfaces.matte(Color(0.3, 0.55, 0.72), 0.6)
		)
	_attach(
		root,
		Vector3(0.0, 1.0, size.z * 0.46),
		Vector3(size.x - 0.06, 1.6, 0.04),
		Surfaces.glass(Color(0.75, 0.88, 0.95, 0.3))
	)
	var chill := OmniLight3D.new()
	chill.position = Vector3(0.0, 1.2, 0.2)
	chill.light_color = Color(0.72, 0.88, 1.0)
	chill.light_energy = 0.55
	chill.omni_range = 2.2
	root.add_child(chill)


## Painted chipboard, the material every shop fitting is actually made of.
func _carcass() -> StandardMaterial3D:
	return Surfaces.textured(Surfaces.wood(Color(0.38, 0.26, 0.18)), Vector3(2.0, 1.0, 1.0), 0.75)


func _attach(root: Node3D, centre: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = centre
	root.add_child(mesh)
	return mesh


func _attach_interactable(node: Node3D, fixture: ContentDefinition, size: Vector3) -> void:
	var interactable := Interactable.new()
	# The rack of packs is a shelf that does something a shelf does not: what is on it can
	# be sold or opened, and standing in front of it is where you decide which.
	if fixture.get_value("tags", []).has("back_door"):
		interactable.kind = Interactable.Kind.DOOR
		interactable.prompt = "Take the delivery in"
		interactable.seconds = 45.0
		interactable.position = node.position + Vector3(0.0, size.y * 0.5, 0.0)
		interactable.scale = size
		add_child(interactable)
		interactables.append(interactable)
		return
	if fixture.get_value("tags", []).has("sealed"):
		interactable.kind = Interactable.Kind.SEALED_RACK
		interactable.prompt = "Open something"
		interactable.seconds = 12.0
		interactable.position = node.position + Vector3(0.0, size.y * 0.5, 0.0)
		interactable.scale = size
		add_child(interactable)
		interactables.append(interactable)
		return
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
		_customers.append(_build_person(_customers.size()))
	while _customers.size() > wanted:
		var last: Node3D = _customers.pop_back()
		last.queue_free()
	# Whoever is at the front is being served; the rest are waiting, and a queue that
	# stands in a line facing the counter is legible from anywhere in the room.
	for index: int in range(_customers.size()):
		var spot: Vector3 = counter_position + Vector3(0.0, 0.0, 1.5 + float(index) * 0.85)
		_customers[index].position = spot
		_customers[index].look_at(counter_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
		_customers[index].rotation.x = 0.0
		_customers[index].rotation.z = 0.0


## A person, from parts: coat, head, hair, bag. Not a character model, but enough that
## four people in a queue look like four people rather than four capsules.
func _build_person(index: int) -> Node3D:
	const COATS: Array[Color] = [
		Color(0.24, 0.29, 0.38),
		Color(0.36, 0.22, 0.22),
		Color(0.22, 0.31, 0.26),
		Color(0.33, 0.3, 0.2),
		Color(0.19, 0.2, 0.24),
	]
	const SKIN: Array[Color] = [
		Color(0.76, 0.6, 0.46),
		Color(0.51, 0.36, 0.26),
		Color(0.87, 0.72, 0.6),
		Color(0.34, 0.24, 0.18),
	]
	const HAIR: Array[Color] = [
		Color(0.12, 0.09, 0.07), Color(0.35, 0.22, 0.11), Color(0.6, 0.55, 0.5)
	]

	var person := Node3D.new()
	var height: float = 1.62 + 0.06 * float(index % 5)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = height * 0.72
	capsule.radius = 0.24
	body.mesh = capsule
	body.material_override = Surfaces.textured(
		Surfaces.fabric(COATS[index % COATS.size()]), Vector3(2.0, 3.0, 1.0), 0.95
	)
	body.position = Vector3(0.0, height * 0.42, 0.0)
	person.add_child(body)

	var head := MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = 0.115
	skull.height = 0.25
	head.mesh = skull
	head.material_override = Surfaces.matte(SKIN[index % SKIN.size()], 0.85)
	head.position = Vector3(0.0, height * 0.86, 0.0)
	person.add_child(head)

	var hair := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.122
	cap.height = 0.2
	hair.mesh = cap
	hair.material_override = Surfaces.matte(HAIR[index % HAIR.size()], 0.95)
	hair.position = Vector3(0.0, height * 0.885, -0.01)
	person.add_child(hair)

	# The binder or the shopping they came in with, which is the reason they are here.
	var carried := MeshInstance3D.new()
	var bag := BoxMesh.new()
	bag.size = Vector3(0.22, 0.28, 0.07)
	carried.mesh = bag
	carried.material_override = Surfaces.matte(
		Color(0.55, 0.42, 0.24) if index % 2 == 0 else Color(0.3, 0.33, 0.38), 0.8
	)
	carried.position = Vector3(0.26, height * 0.45, 0.06)
	person.add_child(carried)

	add_child(person)
	return person


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
		if (
			interactable.kind
			not in [
				Interactable.Kind.CASE,
				Interactable.Kind.RETAIL_SHELF,
				Interactable.Kind.SEALED_RACK,
			]
		):
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
