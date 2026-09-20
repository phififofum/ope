class_name EventOutcome
extends RefCounted

## The result of a cancellable event: whether it may proceed, and if not, who stopped it
## and why. The reason is player-facing text, because "the game said no" with no reason
## is the worst possible feedback in a game about judgement.

var allowed: bool = true
var reason: String = ""
var vetoed_by: String = ""


static func allow() -> EventOutcome:
	return EventOutcome.new()


static func veto(by: String, why: String) -> EventOutcome:
	var outcome := EventOutcome.new()
	outcome.allowed = false
	outcome.vetoed_by = by
	outcome.reason = why
	return outcome
