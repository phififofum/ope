class_name Person
extends RefCounted

## Someone at the counter: their real details, the behaviour you can read off them, and
## the history you may or may not have.
##
## Two things are deliberate. The real details exist separately from whatever document
## they present, so "this ID is genuine but it is not theirs" is expressible. And
## behaviour is correlated with guilt, never determinative of it — nervous legitimate
## customers exist, and a player who convicts on nerves alone must lose money for it.

enum Behaviour { CALM, NERVOUS, RUSHED, CHATTY, HOSTILE }

var id: StringName
var display_name: String
var dob_days: int  ## Date of birth, in days since the world epoch.
var portrait_id: String
var height_cm: int
var archetype_id: StringName

## Ground truth, never sent to a client and never shown to the player.
var is_attempting_fraud: bool = false
var knows_it_is_fake: bool = true

var behaviour: Behaviour = Behaviour.CALM
var nervousness: float = 0.0  ## 0..1, drives the tell and the cat
var patience: float = 1.0

## What the shop knows: transactions, flags, notes. Empty for a stranger.
var history_count: int = 0
var clean_transactions: int = 0
var flags: PackedStringArray = []


func age_days(today: int) -> int:
	return today - dob_days


func age_years(today: int) -> int:
	return int(floor(float(age_days(today)) / 365.25))


## Trust is never shown as a number. This exists so systems can reason about it; the UI
## shows a name, a face and a history instead, because a bar invites optimisation and a
## remembered face invites judgement.
func trust_score() -> float:
	if history_count == 0:
		return 0.0
	var clean_ratio: float = float(clean_transactions) / float(history_count)
	var depth: float = minf(1.0, float(history_count) / 20.0)
	var penalty: float = float(flags.size()) * 0.25
	return clampf(clean_ratio * depth - penalty, -1.0, 1.0)


func is_regular() -> bool:
	return history_count >= 5


## The single ambient signal that fires when something is off. Exactly one, never a UI
## marker, and it fires for some honest people too.
func tell() -> String:
	match behaviour:
		Behaviour.NERVOUS:
			return "glances at the door"
		Behaviour.RUSHED:
			return "checks the time"
		Behaviour.CHATTY:
			return "volunteers information nobody asked for"
		Behaviour.HOSTILE:
			return "stands too close"
		_:
			return ""
