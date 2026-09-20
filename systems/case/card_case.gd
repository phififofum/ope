class_name CardCase
extends RefCounted

## Loop D: sealed product, singles, grading, and a market that moves without you.
##
## The gamble and the scrutiny are the same loop viewed from two sides. You rip packs
## hoping for value; customers bring you cards claiming value. One is hope, the other is
## doubt, and they share every system.
##
## One deliberate design choice lives here: the ledger surfaces your true lifetime return
## on sealed product, plainly and unflatteringly. Not as a lecture — as bookkeeping,
## because a shop owner would know that number.


class Single:
	extends RefCounted
	var set_id: StringName
	var rarity: String
	var market_value: float
	var assessed_grade: float = 0.0  ## the player's prediction, 1..10
	var true_grade: float = 0.0  ## revealed only by the grader
	var authentic: bool = true
	var acquired_day: int = 0
	var cost: float = 0.0


class Consignment:
	extends RefCounted
	var single: Single
	var sent_day: int
	var returns_day: int
	var fee: float


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng

var display: Array[Single] = []
var sealed_stock: Dictionary = {}  ## product id -> boxes
var out_for_grading: Array[Consignment] = []
var market_drift: Dictionary = {}  ## set id -> multiplier

var _day: int = 1


func _init(p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng


func set_day(day: int) -> void:
	_day = day


## Opens one pack. Pull rates are data-driven per set, and a box's expected value is
## below its cost — which is the point, and which the game never hides.
func rip_pack(set_id: StringName, economy: Economy) -> Array[Single]:
	var card_set: ContentDefinition = registry.get_definition(set_id)
	var pulled: Array[Single] = []
	if card_set == null:
		return pulled

	economy.earn(-card_set.get_number("pack_price"), "sealed: pack of %s" % set_id)
	var rarities: Array = card_set.get_value("rarities", [])
	for _card_index: int in range(int(card_set.get_number("cards_per_pack", 10))):
		var roll: float = rng.stream(SeededRng.PULL_RATES).randf()
		var cursor: float = 0.0
		for rarity_spec: Dictionary in rarities:
			cursor += float(rarity_spec.get("pull_rate", 0.0))
			if roll <= cursor:
				pulled.append(_make_single(set_id, rarity_spec))
				break
	var value: float = 0.0
	for single: Single in pulled:
		value += single.market_value
		display.append(single)
	economy.earn(0.0, "sealed: pulled %.2f of value" % value)
	bus.publish(
		EventCatalog.PACK_OPENED, {"set": String(set_id), "cards": pulled.size(), "value": value}
	)
	return pulled


## Buys a single from the public. The offer is a function of the player's own grade
## assessment — over-grade and you overpay; under-grade and the seller walks.
func buy_single(single: Single, offer: float, economy: Economy) -> bool:
	if not economy.spend(offer, "singles: buy-in"):
		return false
	single.cost = offer
	single.acquired_day = _day
	display.append(single)
	return true


func sell_single(single: Single, economy: Economy) -> float:
	if not display.has(single):
		return 0.0
	display.erase(single)
	var price: float = current_value(single)
	economy.earn(price, "singles: sale")
	return price


## Sends a card away to be graded. Weeks later a number comes back that multiplies or
## destroys its value — your own assessment was a prediction, and this is the scoreboard.
func send_for_grading(single: Single, economy: Economy, fee: float = 28.0) -> Consignment:
	if not display.has(single) or not economy.spend(fee, "grading fee"):
		return null
	display.erase(single)
	var consignment := Consignment.new()
	consignment.single = single
	consignment.sent_day = _day
	consignment.returns_day = _day + rng.stream(SeededRng.MARKET).randi_range(18, 40)
	consignment.fee = fee
	out_for_grading.append(consignment)
	return consignment


## Consignments that have come back. The gap between the player's grade and the true one
## is where the real money is won and lost.
func collect_grading(_economy: Economy) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for consignment: Consignment in out_for_grading.duplicate():
		if consignment.returns_day > _day:
			continue
		out_for_grading.erase(consignment)
		var single: Single = consignment.single
		var multiplier: float = _grade_multiplier(single.true_grade)
		single.market_value = single.market_value * multiplier
		display.append(single)
		var result: Dictionary = {
			"set": String(single.set_id),
			"assessed": single.assessed_grade,
			"true_grade": single.true_grade,
			"gap": single.true_grade - single.assessed_grade,
			"value": single.market_value,
		}
		results.append(result)
		bus.publish(EventCatalog.CARD_GRADED, result)
	return results


## Daily drift plus hype spikes. A case left unpriced for a week is a case full of
## mispriced singles.
func advance_day(new_day: int) -> void:
	_day = new_day
	for card_set: ContentDefinition in registry.by_type(&"card_set"):
		var current: float = float(market_drift.get(card_set.id, 1.0))
		var drift: float = rng.stream(SeededRng.MARKET).randfn(0.0, 0.03)
		if _day > int(card_set.get_number("rotates_out_day", 1_000_000)):
			drift -= 0.01  # legal for sale, not for events: demand softens
		market_drift[card_set.id] = clampf(current + drift, 0.35, 4.0)


func current_value(single: Single) -> float:
	return single.market_value * float(market_drift.get(single.set_id, 1.0))


func case_value() -> float:
	var total: float = 0.0
	for single: Single in display:
		total += current_value(single)
	return total


## Shrink: singles are the highest-value goods in the building and the easiest to pocket.
## What the counter cannot see is what goes missing.
func apply_shrink(counter_sightline: float) -> Array[Single]:
	var stolen: Array[Single] = []
	var exposure: float = clampf(1.0 - counter_sightline, 0.0, 1.0)
	for single: Single in display.duplicate():
		if (
			rng.stream(SeededRng.BREAKAGE).randf()
			< 0.0008 * exposure * (1.0 + single.market_value / 200.0)
		):
			display.erase(single)
			stolen.append(single)
	return stolen


func _make_single(set_id: StringName, rarity_spec: Dictionary) -> Single:
	var single := Single.new()
	single.set_id = set_id
	single.rarity = str(rarity_spec.get("rarity", "common"))
	var base: float = float(rarity_spec.get("base_value", 0.1))
	var spread: float = float(rarity_spec.get("value_spread", 0.0))
	single.market_value = maxf(0.02, base + rng.stream(SeededRng.PULL_RATES).randf() * spread)
	single.true_grade = clampf(rng.stream(SeededRng.PULL_RATES).randfn(8.6, 1.1), 1.0, 10.0)
	single.acquired_day = _day
	return single


func _grade_multiplier(grade: float) -> float:
	if grade >= 9.8:
		return 4.5
	if grade >= 9.0:
		return 2.1
	if grade >= 8.0:
		return 1.15
	if grade >= 6.0:
		return 0.7
	return 0.35
