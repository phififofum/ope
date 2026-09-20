class_name Encounter
extends RefCounted

## One transaction at the counter, from approach to consequence.
##
## The encounter knows the ground truth and the player does not. What the player can find
## out is entirely a function of the tools they hold and the time they are willing to
## spend — and the pressure is that spending it costs them somewhere else.

enum Verdict { APPROVE, DECLINE, PARTIAL, CONFISCATE, CALL_IN }
enum Outcome { CORRECT, WRONG_APPROVED, WRONG_DECLINED, OVERCAUTIOUS, MISSED_ESCALATION }

var id: int
var person: Person
var artifacts: Array[Artifact] = []
var transaction_tags: PackedStringArray = []
var value: float = 0.0
var opened_tick: int = 0
var resolved_tick: int = -1
var verdict: Verdict = Verdict.APPROVE
var findings: Array = []
var outcome: Outcome = Outcome.CORRECT


func primary_artifact() -> Artifact:
	return artifacts[0] if not artifacts.is_empty() else null


func is_forged() -> bool:
	for artifact: Artifact in artifacts:
		if artifact.is_forged():
			return true
	return false


## True when the transaction genuinely should not go through — a forged artifact, or a
## rule that fails on a genuine one (an honest customer who is simply too young).
func should_be_refused(engine: RuleEngine, all_tools: PackedStringArray, today: int) -> bool:
	for artifact: Artifact in artifacts:
		for finding: RuleEngine.Finding in engine.evaluate(
			artifact, person, transaction_tags, all_tools, today
		):
			if finding.blocking():
				return true
	return false


## What a player holding [param owned_tools] can actually establish. This is the fairness
## contract in code: if nothing here fails but the artifact is forged, the correct play
## must still be available — declining — and the encounter must not punish it.
func evaluate_with(
	engine: RuleEngine,
	used_tools: PackedStringArray,
	today: int,
	owned_tools: PackedStringArray = PackedStringArray()
) -> Array:
	findings = []
	for artifact: Artifact in artifacts:
		findings.append_array(
			engine.evaluate(artifact, person, transaction_tags, used_tools, today, owned_tools)
		)
	return findings


func has_blocking_failure() -> bool:
	for finding: RuleEngine.Finding in findings:
		if finding.blocking():
			return true
	return false


func has_item_scoped_failure() -> bool:
	for finding: RuleEngine.Finding in findings:
		if finding.item_scoped():
			return true
	return false


func has_unchecked_rule() -> bool:
	for finding: RuleEngine.Finding in findings:
		if finding.status == RuleEngine.Status.UNCHECKED:
			return true
	return false


static func verdict_name(value_to_name: Verdict) -> String:
	match value_to_name:
		Verdict.APPROVE:
			return "approve"
		Verdict.DECLINE:
			return "decline"
		Verdict.PARTIAL:
			return "partial"
		Verdict.CONFISCATE:
			return "confiscate"
		_:
			return "call_in"
