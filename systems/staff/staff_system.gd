class_name StaffSystem
extends RefCounted

## Hiring, and the audit loop it creates.
##
## The rule that keeps this from becoming an idle manager: [b]staff do not remove work,
## they convert work you were doing into work you now have to supervise.[/b] Every hire
## trades a task you performed for an oversight task you did not have before.
##
## Their mistakes are recorded but never reported. You find out by reviewing footage,
## reconciling the register, noticing variance, or receiving the fine three days later.

## Oversight cannot be delegated: no configuration of staff runs the shop without a
## player, and the last third of the work is the part only you can do.
const MAX_COVERAGE: float = 0.7


class Employee:
	extends RefCounted
	var id: StringName
	var display_name: String
	var role_id: StringName
	var training: float = 0.0  ## 0..1, the main lever on error rate
	var fatigue: float = 0.0
	var morale: float = 0.75
	var permissions: PackedStringArray = []
	var shifts_worked: int = 0
	var claimed_experience: float = 0.0
	var actual_experience: float = 0.0

	func lied_on_application() -> bool:
		return claimed_experience - actual_experience > 0.35


class Mistake:
	extends RefCounted
	var employee_id: StringName
	var day: int
	var kind: String
	var cost: float
	var surfaced: bool = false
	var surfaces_via: String


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng

var employees: Array[Employee] = []
var mistakes: Array[Mistake] = []
var applicants: Array[Employee] = []

var _day: int = 1
var _next_index: int = 1


func _init(p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng


func set_day(day: int) -> void:
	_day = day


## Hiring is itself a verification encounter: a work history you can check, references
## you can call, and credentials that may be fabricated.
func generate_applicant(role_id: StringName) -> Employee:
	var employee := Employee.new()
	employee.id = StringName("staff_%d" % _next_index)
	_next_index += 1
	employee.display_name = "Applicant %d" % _next_index
	employee.role_id = role_id
	employee.actual_experience = rng.stream(SeededRng.STAFF_ERROR).randf()
	var exaggeration: float = 0.0
	if rng.stream(SeededRng.STAFF_ERROR).randf() < 0.3:
		exaggeration = rng.stream(SeededRng.STAFF_ERROR).randf_range(0.3, 0.7)
	employee.claimed_experience = clampf(employee.actual_experience + exaggeration, 0.0, 1.0)
	applicants.append(employee)
	return employee


func hire(employee: Employee, economy: Economy) -> EventOutcome:
	var role: ContentDefinition = registry.get_definition(employee.role_id)
	if role == null:
		return EventOutcome.veto("staff", "no such role")
	var outcome: EventOutcome = bus.attempt(
		EventCatalog.HIRE_ATTEMPTED,
		{"role": String(employee.role_id), "claimed": employee.claimed_experience}
	)
	if not outcome.allowed:
		return outcome
	if not economy.spend(role.get_number("wage_per_shift"), "signing shift"):
		return EventOutcome.veto("economy", "cannot cover the first shift")
	applicants.erase(employee)
	employee.training = employee.actual_experience * 0.5
	employees.append(employee)
	return outcome


## Granting permissions is how a player chooses their own late-game difficulty — a much
## better lever than a slider, because it is made of decisions with reasons attached.
func grant_permission(employee: Employee, permission: String) -> void:
	if not employee.permissions.has(permission):
		employee.permissions.append(permission)


func error_rate(employee: Employee, shift_pressure: float) -> float:
	var role: ContentDefinition = registry.get_definition(employee.role_id)
	var base: float = role.get_number("base_error_rate", 0.1) if role != null else 0.1
	return clampf(
		(
			base
			* (1.4 - employee.training)
			* (1.0 + employee.fatigue * 0.8)
			* (1.0 + shift_pressure * 0.5)
		),
		0.0,
		0.9
	)


## Runs a shift's worth of delegated work. Returns the tasks absorbed; the mistakes go
## into the ledger silently, which is the point.
func work_shift(shift_pressure: float, _economy: Economy) -> Dictionary:
	var absorbed: float = 0.0
	var wages: float = 0.0
	for employee: Employee in employees:
		var role: ContentDefinition = registry.get_definition(employee.role_id)
		if role == null:
			continue
		wages += role.get_number("wage_per_shift")
		var coverage: float = minf(role.get_number("coverage", 0.5), MAX_COVERAGE)
		absorbed += coverage * (0.6 + 0.4 * employee.training)
		employee.shifts_worked += 1
		employee.training = clampf(employee.training + 0.02, 0.0, 1.0)
		employee.fatigue = clampf(employee.fatigue + 0.12 * (0.5 + shift_pressure), 0.0, 1.0)

		if rng.stream(SeededRng.STAFF_ERROR).randf() < error_rate(employee, shift_pressure):
			_record_mistake(employee, role)
	return {"tasks_absorbed": absorbed, "wages": wages}


## Spend your own time on someone. Training is the main lever on error rate, and it costs
## the one resource you never have.
func train(employee: Employee, hours: float) -> void:
	employee.training = clampf(employee.training + hours * 0.05, 0.0, 1.0)
	employee.morale = clampf(employee.morale + hours * 0.01, 0.0, 1.0)


## The audit loop: forensic verification on your own shop. Same verb, new object.
func review(surface: String, thoroughness: float) -> Array[Mistake]:
	var found: Array[Mistake] = []
	for mistake: Mistake in mistakes:
		if mistake.surfaced or mistake.surfaces_via != surface:
			continue
		if rng.stream(SeededRng.STAFF_ERROR).randf() < thoroughness:
			mistake.surfaced = true
			found.append(mistake)
	return found


## Mistakes nobody caught, which arrive later as a fine, a complaint or a hole in the
## inventory.
func unsurfaced_cost() -> float:
	var total: float = 0.0
	for mistake: Mistake in mistakes:
		if not mistake.surfaced:
			total += mistake.cost
	return total


func advance_day(new_day: int, economy: Economy) -> Dictionary:
	_day = new_day
	var quit_list: Array[Employee] = []
	for employee: Employee in employees:
		employee.fatigue = maxf(0.0, employee.fatigue - 0.35)
		# Turnover is real: staff quit over pay, treatment and shift patterns, and losing
		# a trained one in Act IV genuinely hurts.
		var quit_chance: float = 0.01 + (1.0 - employee.morale) * 0.06 + employee.fatigue * 0.03
		if rng.stream(SeededRng.STAFF_ERROR).randf() < quit_chance:
			quit_list.append(employee)
	for employee: Employee in quit_list:
		employees.erase(employee)

	var delayed: float = 0.0
	for mistake: Mistake in mistakes:
		if not mistake.surfaced and _day - mistake.day >= 3 and mistake.surfaces_via == "fine":
			mistake.surfaced = true
			delayed += mistake.cost
			economy.spend(mistake.cost, "fine from an unnoticed staff error")
	return {"quit": quit_list.size(), "delayed_fines": delayed}


func _record_mistake(employee: Employee, role: ContentDefinition) -> void:
	var surfaces: Array = role.get_value("audit_surface", ["camera review"])
	var mistake := Mistake.new()
	mistake.employee_id = employee.id
	mistake.day = _day
	mistake.kind = str(rng.pick(SeededRng.STAFF_ERROR, surfaces))
	mistake.cost = rng.stream(SeededRng.STAFF_ERROR).randf_range(8.0, 180.0)
	mistake.surfaces_via = (
		"fine"
		if (
			employee.permissions.has("handle_age_restricted")
			and rng.stream(SeededRng.STAFF_ERROR).randf() < 0.3
		)
		else "review"
	)
	mistakes.append(mistake)
	bus.publish(
		EventCatalog.STAFF_ERROR_MADE,
		{"employee": String(employee.id), "kind": mistake.kind, "cost": mistake.cost}
	)
