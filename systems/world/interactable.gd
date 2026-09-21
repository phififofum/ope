class_name Interactable
extends Area3D

## Anything in the room the player can use: a register, a griddle, the display case, a
## shelf, the cat's bowl.
##
## Every one carries its own prompt and its own cost in seconds, because the world is the
## interface -- there is no menu of available actions anywhere.

signal used(by: Node3D)

enum Kind {
	COUNTER,
	KITCHEN_STATION,
	LIBRARY_SHELF,
	RETAIL_SHELF,
	SEALED_RACK,
	CASE,
	TABLE,
	BIN,
	TOOL,
	CAT_SPOT,
	DOOR,
}

@export var kind: Kind = Kind.COUNTER
@export var prompt: String = "Use"
@export var seconds: float = 2.0
@export var tool_id: String = ""
@export var station_name: String = ""

var enabled: bool = true


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box
	add_child(shape)
	collision_layer = 2
	collision_mask = 0


func use(by: Node3D) -> bool:
	if not enabled:
		return false
	used.emit(by)
	return true


func prompt_text() -> String:
	return prompt if enabled else "%s (unavailable)" % prompt
