class_name GameLibrary
extends RefCounted

## The wall of games: what is on the shelf, what is out, and what came back incomplete.
##
## The component check is the standout mechanic of the floor and it runs on the same
## checklist verb as the counter — which is why the tutorial opens with it. It is the
## gentlest possible verification: a checklist with no adversary behind it.


class Copy:
	extends RefCounted
	var game_id: StringName
	var copy_index: int
	var condition: float = 1.0  ## 1.0 shelf-fresh, 0.0 unlendable
	var missing: Dictionary = {}  ## part -> count missing
	var on_loan_to: StringName = &""
	var loaned_tick: int = 0
	var due_tick: int = 0
	var checked: bool = true

	func is_complete() -> bool:
		return missing.is_empty()

	func is_lendable() -> bool:
		return on_loan_to == &"" and is_complete() and condition > 0.25


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng

var copies: Array[Copy] = []
var awaiting_check: Array[Copy] = []
var incomplete_count: int = 0
var checks_skipped: int = 0


func _init(p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng


func acquire(game_id: StringName, count: int = 1) -> void:
	var game: ContentDefinition = registry.get_definition(game_id)
	if game == null or not bool(game.get_value("library_eligible", true)):
		return
	for index: int in range(count):
		var copy := Copy.new()
		copy.game_id = game_id
		copy.copy_index = _next_index(game_id)
		copies.append(copy)


func lendable(game_id: StringName = &"") -> Array[Copy]:
	var out: Array[Copy] = []
	for copy: Copy in copies:
		if copy.is_lendable() and (game_id == &"" or copy.game_id == game_id):
			out.append(copy)
	return out


## Lends a copy for a play session. The copy is gone until they finish -- which is what
## makes the table mix a bet and the shelf a finite resource.
func lend(copy: Copy, person_id: StringName, tick: int, session_ticks: int = 12000) -> EventOutcome:
	var outcome: EventOutcome = bus.attempt(
		EventCatalog.LOAN_ATTEMPTED, {"game": String(copy.game_id), "person": String(person_id)}
	)
	if not outcome.allowed:
		return outcome
	copy.on_loan_to = person_id
	copy.loaned_tick = tick
	copy.due_tick = tick + session_ticks
	copy.checked = false
	return outcome


## Copies whose session has ended and which are coming back to the counter now.
func due_back(tick: int) -> Array[Copy]:
	var due: Array[Copy] = []
	for copy: Copy in copies:
		if copy.on_loan_to != &"" and tick >= copy.due_tick:
			due.append(copy)
	return due


## A copy comes back. Play wears it, and parts go missing in proportion to how easy they
## are to lose — which is why a 400-component heavy game after a six-hour session is a
## real decision about whether you have time to check it.
func return_copy(copy: Copy, table_hours: float) -> void:
	copy.on_loan_to = &""
	copy.condition = maxf(0.0, copy.condition - 0.01 - table_hours * 0.004)
	var game: ContentDefinition = registry.get_definition(copy.game_id)
	if game != null:
		for component: Dictionary in game.get_value("components", []):
			var loss_weight: float = float(component.get("loss_weight", 0.2))
			if rng.stream(SeededRng.BREAKAGE).randf() < loss_weight * 0.05:
				var part: String = str(component.get("part", "piece"))
				copy.missing[part] = int(copy.missing.get(part, 0)) + 1
	awaiting_check.append(copy)
	bus.publish(EventCatalog.GAME_RETURNED, {"game": String(copy.game_id), "hours": table_hours})


## How long a check takes: light filler, ten seconds; heavy game, a real decision.
func check_seconds(copy: Copy) -> float:
	var game: ContentDefinition = registry.get_definition(copy.game_id)
	if game == null:
		return 10.0
	var pieces: int = 0
	for component: Dictionary in game.get_value("components", []):
		pieces += int(component.get("count", 0))
	return clampf(6.0 + float(pieces) * 0.18, 6.0, 180.0)


## Run the checklist. Returns what was found; an unchecked copy goes back on the shelf
## and becomes somebody's ruined evening three days later.
func perform_check(copy: Copy) -> Dictionary:
	awaiting_check.erase(copy)
	copy.checked = true
	if not copy.is_complete():
		incomplete_count += 1
	var result: Dictionary = {
		"game": String(copy.game_id),
		"complete": copy.is_complete(),
		"missing": copy.missing.duplicate(),
		"condition": copy.condition,
	}
	bus.publish(EventCatalog.COMPONENT_CHECK_RESOLVED, result)
	return result


func skip_check(copy: Copy) -> void:
	awaiting_check.erase(copy)
	checks_skipped += 1
	copy.checked = false


## Replace missing parts. Costs money and time, and is the only way a game returns to
## the lending shelf.
func repair(copy: Copy, economy: Economy) -> bool:
	if copy.is_complete():
		return true
	var pieces: int = 0
	for count: int in copy.missing.values():
		pieces += count
	if not economy.spend(float(pieces) * 1.25 + 4.0, "library repair"):
		return false
	copy.missing.clear()
	copy.condition = minf(1.0, copy.condition + 0.05)
	return true


func stats() -> Dictionary:
	var on_loan: int = 0
	var unlendable: int = 0
	for copy: Copy in copies:
		if copy.on_loan_to != &"":
			on_loan += 1
		elif not copy.is_lendable():
			unlendable += 1
	return {
		"copies": copies.size(),
		"on_loan": on_loan,
		"unlendable": unlendable,
		"awaiting_check": awaiting_check.size(),
		"incomplete_found": incomplete_count,
		"checks_skipped": checks_skipped,
	}


func _next_index(game_id: StringName) -> int:
	var count: int = 0
	for copy: Copy in copies:
		if copy.game_id == game_id:
			count += 1
	return count + 1
