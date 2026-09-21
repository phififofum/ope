class_name CardCase
extends RefCounted

## Loop D: sealed product, singles, grading, and a market that moves without you.
##
## The gamble and the scrutiny are the same loop viewed from two sides. You rip packs
## hoping for value; customers bring you cards claiming value. One is hope, the other is
## doubt, and they share every system.
##
## Every sealed unit in the building is the same decision twice a day: sell it across the
## counter for a known margin, or open it and find out. That is the whole hook, and it is
## deliberately a real choice rather than a good one -- [method rip] charges the shelf
## price you gave up, so a rip is measured against the sale you could have made.
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
	## Pulled out of a pack rather than bought over the counter. The sealed ledger only
	## means anything if it can tell those two apart.
	var from_rip: bool = false
	## On the wall instead of in the case: not for sale, and drawing people in.
	var on_display: bool = false


class Consignment:
	extends RefCounted
	var single: Single
	var sent_day: int
	var returns_day: int
	var fee: float


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng

## Priced and for sale. The case is inventory, and inventory left unworked is money
## standing still.
var stock: Array[Single] = []
## Behind glass and off the buylist: the chase card people come in to look at. It earns
## nothing until you take it down, which is exactly the tension it is there to create.
var showcase: Array[Single] = []
var showcase_capacity: int = 6
var out_for_grading: Array[Consignment] = []
var market_drift: Dictionary = {}  ## set id -> multiplier

## Lifetime sealed bookkeeping, the number the design promises not to hide.
var sealed_ripped: int = 0
var sealed_forgone: float = 0.0  ## shelf price of every unit opened instead of sold
var sealed_pulled_value: float = 0.0  ## paper value at the moment of the pull
var sealed_realised: float = 0.0  ## cash actually taken for rip-sourced singles
var sealed_sold: int = 0
var sealed_revenue: float = 0.0

var _day: int = 1


func _init(p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng


func set_day(day: int) -> void:
	_day = day


## Opens one pack at the counter price. Pull rates are data-driven per set, and a pack's
## expected value is below what the pack sells for — which is the point, and which the
## game never hides.
##
## [param hits_removed] is the resealer's work: the pack opens, the commons are all
## present, and the card worth having left the building before you ever saw it.
func rip_pack(set_id: StringName, economy: Economy, hits_removed: bool = false) -> Array[Single]:
	var card_set: ContentDefinition = registry.get_definition(set_id)
	var pulled: Array[Single] = []
	if card_set == null:
		return pulled

	economy.earn(-card_set.get_number("pack_price"), "sealed: pack of %s" % set_id)
	sealed_ripped += 1
	sealed_forgone += card_set.get_number("pack_price")
	var value: float = _open_one_pack(card_set, pulled, hits_removed)
	economy.earn(0.0, "sealed: pulled %.2f of value" % value)
	sealed_pulled_value += value
	(
		bus
		. publish(
			EventCatalog.PACK_OPENED,
			{
				"set": String(set_id),
				"packs": 1,
				"cards": pulled.size(),
				"value": value,
				"forgone": card_set.get_number("pack_price"),
				"resealed": hits_removed,
			}
		)
	)
	return pulled


## Opens a sealed unit the shop already owns: a pack off the impulse rack, a box off the
## shelf. The unit leaves inventory, so the gamble costs the sale that unit would have
## been — which is the honest way to price it, and the reason [method sealed_ledger] is
## worth reading.
func rip(product_id: StringName, stock_room: Inventory, economy: Economy) -> Dictionary:
	var product: ContentDefinition = registry.get_definition(product_id)
	if product == null:
		return {"opened": false, "reason": "no such product"}
	var sealed_spec: Dictionary = product.get_value("sealed", {})
	var card_set: ContentDefinition = registry.get_definition(
		StringName(str(sealed_spec.get("card_set", "")))
	)
	if card_set == null:
		return {"opened": false, "reason": "not sealed product"}

	var allowed: EventOutcome = (
		bus
		. attempt(
			EventCatalog.SEALED_OPEN_ATTEMPTED,
			{
				"product": String(product_id),
				"set": String(card_set.id),
				"packs": int(sealed_spec.get("packs", 1)),
				"shelf_price": product.get_number("market_price"),
			}
		)
	)
	if not allowed.allowed:
		return {"opened": false, "reason": allowed.reason}

	var taken: Dictionary = stock_room.take_unit(product_id)
	if not bool(taken["ok"]):
		return {"opened": false, "reason": "none in stock"}

	var resealed: bool = bool(taken["suspect"])
	var packs: int = maxi(1, int(sealed_spec.get("packs", 1)))
	var forgone: float = product.get_number("market_price")
	var pulled: Array[Single] = []
	var value: float = 0.0
	for _pack_index: int in range(packs):
		value += _open_one_pack(card_set, pulled, resealed)

	sealed_ripped += 1
	sealed_forgone += forgone
	sealed_pulled_value += value
	economy.earn(0.0, "sealed: opened %s, pulled %.2f" % [product_id, value])

	var best: Single = null
	for single: Single in pulled:
		if best == null or single.market_value > best.market_value:
			best = single
	var result: Dictionary = {
		"opened": true,
		"product": String(product_id),
		"set": String(card_set.id),
		"packs": packs,
		"cards": pulled.size(),
		"value": value,
		"forgone": forgone,
		"resealed": resealed,
		"best_value": best.market_value if best != null else 0.0,
		"best_rarity": best.rarity if best != null else "",
	}
	bus.publish(EventCatalog.PACK_OPENED, result)
	return result


## A sealed unit sold across the counter instead of opened. Recorded so the ledger can
## put the two decisions side by side, which is the only way the comparison is honest.
func record_sealed_sale(price: float) -> void:
	sealed_sold += 1
	sealed_revenue += price


## The number a shop owner would know and a gambler would rather not: what every unit you
## opened was worth on the shelf, against what opening them actually returned. Paper value
## still sitting in the case counts, because it is genuinely yours -- it is simply not
## money yet.
func sealed_ledger() -> Dictionary:
	var unsold: float = 0.0
	for single: Single in stock + showcase:
		if single.from_rip:
			unsold += current_value(single)
	var returned: float = sealed_realised + unsold
	return {
		"units_ripped": sealed_ripped,
		"retail_forgone": sealed_forgone,
		"pulled_value": sealed_pulled_value,
		"realised": sealed_realised,
		"unsold_value": unsold,
		"return_ratio": returned / sealed_forgone if sealed_forgone > 0.0 else 0.0,
		"units_sold_sealed": sealed_sold,
		"sealed_revenue": sealed_revenue,
	}


## Buys a single from the public. The offer is a function of the player's own grade
## assessment — over-grade and you overpay; under-grade and the seller walks.
func buy_single(single: Single, offer: float, economy: Economy) -> bool:
	if not economy.spend(offer, "singles: buy-in"):
		return false
	single.cost = offer
	single.acquired_day = _day
	stock.append(single)
	return true


## Sells a single out of the case. A card on display is not for sale until it comes off
## the wall, which is the cost of having something worth looking at.
func sell_single(single: Single, economy: Economy) -> float:
	if not stock.has(single):
		return 0.0
	stock.erase(single)
	var price: float = current_value(single)
	economy.earn(price, "singles: sale")
	if single.from_rip:
		sealed_realised += price
	return price


## Puts a card on the wall. It stops being stock and starts being the reason somebody
## walks in -- and the draw is worth having only while the card is worth looking at.
func put_on_display(single: Single) -> bool:
	if showcase.size() >= showcase_capacity or not stock.has(single):
		return false
	stock.erase(single)
	single.on_display = true
	showcase.append(single)
	return true


func take_off_display(single: Single) -> bool:
	if not showcase.has(single):
		return false
	showcase.erase(single)
	single.on_display = false
	stock.append(single)
	return true


## What the wall is worth in footfall rather than cash. Diminishing, because the second
## expensive card in a case impresses nobody half as much as the first one did.
func display_draw() -> float:
	var shown: float = 0.0
	for single: Single in showcase:
		shown += current_value(single)
	return clampf(log(1.0 + shown / 120.0) * 0.28, 0.0, 1.1)


## Sends a card away to be graded. Weeks later a number comes back that multiplies or
## destroys its value — your own assessment was a prediction, and this is the scoreboard.
func send_for_grading(single: Single, economy: Economy, fee: float = 28.0) -> Consignment:
	if not stock.has(single) or not economy.spend(fee, "grading fee"):
		return null
	stock.erase(single)
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
		stock.append(single)
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
	for single: Single in stock + showcase:
		total += current_value(single)
	return total


## Shrink: singles are the highest-value goods in the building and the easiest to pocket.
## What the counter cannot see is what goes missing.
func apply_shrink(counter_sightline: float) -> Array[Single]:
	var stolen: Array[Single] = []
	var exposure: float = clampf(1.0 - counter_sightline, 0.0, 1.0)
	for single: Single in stock.duplicate():
		if (
			rng.stream(SeededRng.BREAKAGE).randf()
			< 0.0008 * exposure * (1.0 + single.market_value / 200.0)
		):
			stock.erase(single)
			stolen.append(single)
	# The wall is locked and lit and in everybody's eyeline. That is what it is for, and
	# it is why the most valuable card in the building is the safest one.
	for single: Single in showcase.duplicate():
		if rng.stream(SeededRng.BREAKAGE).randf() < 0.0002 * exposure:
			showcase.erase(single)
			single.on_display = false
			stolen.append(single)
	return stolen


## One pack: a fixed number of pulls against the set's own table. Appends to
## [param into] and returns what it was worth the moment it hit the table.
func _open_one_pack(card_set: ContentDefinition, into: Array[Single], hits_removed: bool) -> float:
	var rarities: Array = card_set.get_value("rarities", [])
	if rarities.is_empty():
		return 0.0
	var value: float = 0.0
	for _card_index: int in range(int(card_set.get_number("cards_per_pack", 10))):
		var roll: float = rng.stream(SeededRng.PULL_RATES).randf()
		var cursor: float = 0.0
		for rarity_index: int in range(rarities.size()):
			cursor += float((rarities[rarity_index] as Dictionary).get("pull_rate", 0.0))
			if roll > cursor:
				continue
			# A resealed box still has every common in it. What it does not have is the
			# reason anybody buys a sealed box.
			var spec: Dictionary = rarities[mini(rarity_index, 1) if hits_removed else rarity_index]
			var single: Single = _make_single(card_set.id, spec)
			single.from_rip = true
			into.append(single)
			stock.append(single)
			value += single.market_value
			break
	return value


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
