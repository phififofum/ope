class_name Economy
extends RefCounted

## Three currencies, deliberately not convertible.
##
## Money buys things. Reputation buys customers. Standing buys permission. A player who
## is rich but disreputable and one who is broke but trusted face genuinely different
## problems, and that is what stops a campaign collapsing into one optimisation curve.

const STARTING_MONEY: float = 1200.0
const STRIKE_SUSPENSION_DAYS: int = 14
const STRIKE_DECAY_DAYS: int = 21

var bus: EventBus

var money: float = STARTING_MONEY
var reputation: float = 0.0  ## -10 grim .. +10 beloved
var standing: int = 0  ## regulatory record; gates the licence tree

var licences: Dictionary = {}  ## licence id -> {held: bool, strikes: int, suspended_until: int}
var day: int = 1

var _ledger: Array[Dictionary] = []


func _init(p_bus: EventBus) -> void:
	bus = p_bus


func spend(amount: float, reason: String) -> bool:
	if amount > money:
		return false
	money -= amount
	_record("spend", -amount, reason)
	return true


func earn(amount: float, reason: String) -> void:
	money += amount
	_record("earn", amount, reason)


## Reputation moves slowly and is never shown as a number: the UI shows the room, the
## regulars and the queue.
func adjust_reputation(delta: float, reason: String) -> void:
	reputation = clampf(reputation + delta, -10.0, 10.0)
	_record("reputation", delta, reason)
	bus.publish(EventCatalog.REPUTATION_CHANGED, {"reputation": reputation, "reason": reason})


func grant_licence(licence_id: StringName) -> void:
	licences[licence_id] = {"held": true, "strikes": 0, "suspended_until": 0, "last_strike_day": 0}
	standing += 1
	bus.publish(EventCatalog.LICENCE_GRANTED, {"licence": String(licence_id)})


func holds(licence_id: StringName) -> bool:
	var entry: Dictionary = licences.get(licence_id, {})
	if not bool(entry.get("held", false)):
		return false
	return int(entry.get("suspended_until", 0)) <= day


## A compliance failure. Three strikes suspends the licence; strikes decay with clean
## operation and cannot be bought off, which is the whole reason standing is a separate
## currency.
func issue_strike(licence_id: StringName, reason: String) -> Dictionary:
	var entry: Dictionary = licences.get(
		licence_id, {"held": true, "strikes": 0, "suspended_until": 0}
	)
	entry["strikes"] = int(entry.get("strikes", 0)) + 1
	entry["last_strike_day"] = day

	var strikes: int = int(entry["strikes"])
	var fine: float = [0.0, 250.0, 800.0, 1500.0][mini(strikes, 3)]
	var consequence: String = "warning"
	if strikes == 2:
		consequence = "compliance_period"
	elif strikes >= 3:
		consequence = "suspended"
		entry["suspended_until"] = day + STRIKE_SUSPENSION_DAYS
		standing = maxi(0, standing - 1)

	licences[licence_id] = entry
	money -= fine
	_record("fine", -fine, reason)
	adjust_reputation(-0.3, "strike")

	var payload: Dictionary = {
		"licence": String(licence_id),
		"strikes": strikes,
		"fine": fine,
		"consequence": consequence,
		"reason": reason,
	}
	bus.publish(EventCatalog.STRIKE_ISSUED, payload)
	return payload


## True while a licence is inside its compliance-check period, when undercover attempts
## become markedly more frequent — the game gets harder exactly when you can least
## afford it.
func under_compliance_check(licence_id: StringName) -> bool:
	var entry: Dictionary = licences.get(licence_id, {})
	return int(entry.get("strikes", 0)) >= 2 and int(entry.get("suspended_until", 0)) <= day


func advance_day(new_day: int) -> void:
	day = new_day
	for licence_id: StringName in licences.keys():
		var entry: Dictionary = licences[licence_id]
		var last: int = int(entry.get("last_strike_day", 0))
		if int(entry.get("strikes", 0)) > 0 and day - last >= STRIKE_DECAY_DAYS:
			entry["strikes"] = int(entry["strikes"]) - 1
			entry["last_strike_day"] = day
			licences[licence_id] = entry


func pay_costs(rent: float, wages: float, utilities: float) -> void:
	money -= rent + wages + utilities
	_record("overheads", -(rent + wages + utilities), "rent, wages, utilities")


func is_insolvent() -> bool:
	return money < -2000.0


func ledger() -> Array[Dictionary]:
	return _ledger.duplicate()


## What the ledger says about sealed product, plainly and unflatteringly. A game about
## scrutiny should not be coy about the one set of odds the player is most tempted not
## to look at.
func sealed_product_return() -> Dictionary:
	var spent: float = 0.0
	var returned: float = 0.0
	for entry: Dictionary in _ledger:
		if str(entry.get("reason", "")).begins_with("sealed:"):
			if float(entry["amount"]) < 0.0:
				spent += absf(float(entry["amount"]))
			else:
				returned += float(entry["amount"])
	return {
		"spent": spent,
		"returned": returned,
		"net": returned - spent,
		"ratio": (returned / spent) if spent > 0.0 else 0.0,
	}


func snapshot() -> Dictionary:
	return {
		"money": money,
		"reputation": reputation,
		"standing": standing,
		"licences": licences.duplicate(true),
		"day": day,
	}


func restore(data: Dictionary) -> void:
	money = float(data.get("money", STARTING_MONEY))
	reputation = float(data.get("reputation", 0.0))
	standing = int(data.get("standing", 0))
	licences = data.get("licences", {})
	day = int(data.get("day", 1))


func _record(kind: String, amount: float, reason: String) -> void:
	_ledger.append({"day": day, "kind": kind, "amount": amount, "reason": reason})
	if kind in ["earn", "spend", "fine", "overheads"]:
		bus.publish(EventCatalog.MONEY_CHANGED, {"money": money, "delta": amount, "reason": reason})
