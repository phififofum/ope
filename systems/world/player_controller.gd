class_name PlayerController
extends CharacterBody3D

## First person, two hands, no pause.
##
## The hands are the design: one artifact, one tool, and a limitation that is a feature.
## Everything the player can do costs seconds of the same budget the queue is spending.

signal looked_at(target: Node3D)
signal picked_up(item_name: String)
signal dropped(item_name: String)

const WALK_SPEED: float = 3.1
const RUN_SPEED: float = 4.6
const ACCELERATION: float = 12.0
const MOUSE_SENSITIVITY: float = 0.0022
const INTERACT_RANGE: float = 2.4

@export var can_run: bool = true

var held_artifact: Artifact
var held_tool_id: String = ""
var look_sensitivity: float = MOUSE_SENSITIVITY
var invert_y: bool = false
var head_bob_enabled: bool = true

var _camera: Camera3D
var _ray: RayCast3D
var _pitch: float = 0.0
var _bob_phase: float = 0.0
var _last_target: Node3D


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 1.62, 0.0)
	_camera.fov = 75.0
	add_child(_camera)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0.0, 0.0, -INTERACT_RANGE)
	_ray.collide_with_areas = true
	_camera.add_child(_ray)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.32
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(shape)


func camera() -> Camera3D:
	return _camera


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		rotate_y(-motion.relative.x * look_sensitivity)
		var pitch_delta: float = motion.relative.y * look_sensitivity * (1.0 if invert_y else -1.0)
		_pitch = clampf(_pitch + pitch_delta, -1.4, 1.4)
		_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed: float = RUN_SPEED if can_run and Input.is_action_pressed("run") else WALK_SPEED

	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if head_bob_enabled and direction.length() > 0.1 and is_on_floor():
		_bob_phase += delta * speed * 1.6
		_camera.position.y = 1.62 + sin(_bob_phase) * 0.018
	else:
		_camera.position.y = move_toward(_camera.position.y, 1.62, delta)

	_update_target()


## What the player is looking at, so the HUD can offer one prompt and no more.
func current_target() -> Node3D:
	if _ray == null or not _ray.is_colliding():
		return null
	var collider: Object = _ray.get_collider()
	return collider as Node3D


func hands_full() -> bool:
	return held_artifact != null and not held_tool_id.is_empty()


func take_artifact(artifact: Artifact, label: String) -> void:
	held_artifact = artifact
	picked_up.emit(label)


func take_tool(tool_id: String) -> void:
	held_tool_id = tool_id
	picked_up.emit(tool_id)


## Set it down and pick something else up. Your hands are finite, and losing your place
## is part of the cost of looking closely.
func put_down_artifact() -> Artifact:
	var artifact: Artifact = held_artifact
	held_artifact = null
	if artifact != null:
		dropped.emit("artifact")
	return artifact


func put_down_tool() -> String:
	var tool_id: String = held_tool_id
	held_tool_id = ""
	if not tool_id.is_empty():
		dropped.emit(tool_id)
	return tool_id


func _update_target() -> void:
	var target: Node3D = current_target()
	if target != _last_target:
		_last_target = target
		looked_at.emit(target)
