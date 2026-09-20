class_name VerificationEngine
extends RefCounted

## Builds encounters, scores verdicts, and reports what happened on the bus.
##
## One engine for every scenario family. An ID at the bar, a trade-in record, a manifest
## at the back door and a card across the glass are the same machinery with different
## data — which is the architecture requirement, not an optimisation.

const CORRECT_REFUSAL_REPUTATION: float = 0.0
const WRONG_REFUSAL_REPUTATION: float = -0.4
const OVERCAUTIOUS_REPUTATION: float = -0.15
const APPROVED_FORGERY_REPUTATION: float = -1.0

var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng
var rules: RuleEngine
var forgeries: ForgeryGenerator

var _next_id: int = 1
var _today: int = 0


func _init(p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng
	rules = RuleEngine.new(p_registry)
	forgeries = ForgeryGenerator.new(p_registry, p_rng)


func set_today(day: int) -> void:
	_today = day


func today() -> int:
	return _today


## Creates an encounter. [param forged] is decided by the director, not rolled here —
## suspicious encounters are scheduled content, not luck.
func create(
	document_type_id: StringName,
	person: Person,
	transaction_tags: PackedStringArray,
	forged: bool,
	max_tier: int,
	value: float = 0.0
) -> Encounter:
	var document_type: ContentDefinition = registry.get_definition(document_type_id)
	if document_type == null:
		return null

	var encounter := Encounter.new()
	encounter.id = _next_id
	_next_id += 1
	encounter.person = person
	encounter.transaction_tags = transaction_tags
	encounter.value = value
	encounter.artifacts.append(
		(
			forgeries.generate_forged(document_type, person, _today, max_tier)
			if forged
			else forgeries.generate_genuine(document_type, person, _today)
		)
	)

	# Behaviour is correlated with guilt, never determinative. Honest people get nervous
	# and fraudsters can be calm; the correlation is real and the noise is the point.
	var roll: float = rng.stream(SeededRng.FORGERY).randf()
	if forged:
		person.is_attempting_fraud = true
		person.nervousness = clampf(0.35 + roll * 0.5, 0.0, 1.0)
	else:
		person.nervousness = clampf(roll * 0.45, 0.0, 1.0)
	person.behaviour = (
		Person.Behaviour.NERVOUS if person.nervousness > 0.55 else Person.Behaviour.CALM
	)

	bus.publish(
		EventCatalog.CUSTOMER_SPAWNED,
		{"encounter": encounter.id, "person": String(person.id), "tags": transaction_tags}
	)
	return encounter


## Which of an encounter's forgery vectors [param owned_tools] can actually catch. The
## fairness rule lives here: if this is empty and the artifact is forged, the encounter
## must still be resolvable by refusing.
func detectable_vectors(encounter: Encounter, owned_tools: PackedStringArray) -> PackedStringArray:
	var detectable: PackedStringArray = []
	for artifact: Artifact in encounter.artifacts:
		for vector_id: StringName in artifact.applied_vectors:
			var vector: ContentDefinition = registry.get_definition(vector_id)
			if vector == null:
				continue
			for tool_id: String in vector.get_value("detectable_by", []):
				if owned_tools.has(tool_id):
					detectable.append(String(vector_id))
					break
	return detectable


## Scores a verdict against ground truth and publishes the result.
##
## Being right is not always comfortable, and the scoring reflects that: refusing an
## honest customer costs reputation, refusing a fraudster costs nothing, and approving a
## forgery costs a great deal later. Declining when you genuinely cannot tell is always
## available and only mildly expensive — uncertainty should feel like a tool gap, never
## like unfairness.
func resolve(
	encounter: Encounter, verdict: Encounter.Verdict, owned_tools: PackedStringArray, tick: int
) -> Dictionary:
	encounter.verdict = verdict
	encounter.resolved_tick = tick
	encounter.evaluate_with(rules, owned_tools, _today)

	var all_tools: PackedStringArray = _all_tool_ids()
	var truly_bad: bool = (
		encounter.is_forged() or encounter.should_be_refused(rules, all_tools, _today)
	)
	var refused: bool = verdict != Encounter.Verdict.APPROVE

	var reputation_delta: float = 0.0
	if truly_bad and refused:
		encounter.outcome = Encounter.Outcome.CORRECT
		reputation_delta = CORRECT_REFUSAL_REPUTATION
	elif truly_bad and not refused:
		encounter.outcome = Encounter.Outcome.WRONG_APPROVED
		reputation_delta = APPROVED_FORGERY_REPUTATION
	elif not truly_bad and refused:
		# An honest customer turned away. Cheaper when the player genuinely could not
		# check — a tool gap is the game's fault, not theirs.
		encounter.outcome = (
			Encounter.Outcome.OVERCAUTIOUS
			if encounter.has_unchecked_rule()
			else Encounter.Outcome.WRONG_DECLINED
		)
		reputation_delta = (
			OVERCAUTIOUS_REPUTATION
			if encounter.outcome == Encounter.Outcome.OVERCAUTIOUS
			else WRONG_REFUSAL_REPUTATION
		)
	else:
		encounter.outcome = Encounter.Outcome.CORRECT

	var result: Dictionary = {
		"encounter": encounter.id,
		"verdict": Encounter.verdict_name(verdict),
		"was_forged": encounter.is_forged(),
		"should_refuse": truly_bad,
		"outcome": encounter.outcome,
		"reputation_delta": reputation_delta,
		"value": encounter.value,
		"detectable": detectable_vectors(encounter, owned_tools),
		"person": String(encounter.person.id),
	}
	bus.publish(EventCatalog.VERIFICATION_RESOLVED, result)
	return result


## Total seconds of inspection for [param tool_ids]. Every tool costs time, and the queue
## does not wait.
func inspection_cost(tool_ids: PackedStringArray) -> float:
	var seconds: float = 0.0
	for tool_id: String in tool_ids:
		var tool: ContentDefinition = registry.get_definition(StringName(tool_id))
		if tool != null:
			seconds += tool.get_number("inspection_seconds", 0.0)
	return bus.query(EventCatalog.INSPECTION_TIME_REQUESTED, {"tools": tool_ids}, seconds)


func _all_tool_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for tool: ContentDefinition in registry.by_type(&"tool"):
		ids.append(String(tool.id))
	return ids
