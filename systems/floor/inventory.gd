class_name Inventory
extends RefCounted

## Stock: what is on the shelf, what is in the back, what is going off, and what is on
## its way.
##
## The neglect-punisher is expiry. Everything else here exists so that the kitchen can
## run out of bread at 08:00 and have that be a floor failure that lands on the kitchen,
## rather than an abstraction.


class Lot:
	extends RefCounted
	var product_id: StringName
	var units: int
	var expires_day: int
	## Came in on a delivery the supplier got wrong. Sealed product that is wrong in this
	## way is wrong in a specific way -- the hits are already gone -- and you find out
	## either by opening it or by the customer who does.
	var suspect: bool = false

	func _init(
		p_product: StringName, p_units: int, p_expires: int, p_suspect: bool = false
	) -> void:
		product_id = p_product
		units = p_units
		expires_day = p_expires
		suspect = p_suspect


class Delivery:
	extends RefCounted
	var supplier_id: StringName
	var lines: Dictionary = {}  ## product id -> units
	var arrives_day: int
	var cost: float
	var verified: bool = false
	var problem: String = ""


var registry: ContentRegistry
var bus: EventBus

var shelf: Dictionary = {}  ## product id -> units faced and sellable
## How many of the faced units came out of a bad lot. Which physical box you pick up is
## not a thing the player can see, so it is not a thing the simulation rolls for.
var shelf_suspect: Dictionary = {}  ## product id -> units of the above that are suspect
var back_room: Array[Lot] = []
var incoming: Array[Delivery] = []
var spoiled_units: int = 0
var lost_sales: int = 0

var _day: int = 1


func _init(p_registry: ContentRegistry, p_bus: EventBus) -> void:
	registry = p_registry
	bus = p_bus


func set_day(day: int) -> void:
	_day = day


func units_on_shelf(product_id: StringName) -> int:
	return int(shelf.get(product_id, 0))


func units_in_back(product_id: StringName) -> int:
	var total: int = 0
	for lot: Lot in back_room:
		if lot.product_id == product_id:
			total += lot.units
	return total


func total_units(product_id: StringName) -> int:
	return units_on_shelf(product_id) + units_in_back(product_id)


## Order from a supplier. Cash leaves now; goods arrive on a lead time — over-ordering
## perishables is the classic beginner's grave, and it should stay one.
func order(
	supplier_id: StringName, lines: Dictionary, economy: Economy, rng: SeededRng
) -> Delivery:
	var supplier: ContentDefinition = registry.get_definition(supplier_id)
	if supplier == null:
		return null

	var cost: float = 0.0
	for product_id: StringName in lines.keys():
		var product: ContentDefinition = registry.get_definition(product_id)
		if product != null:
			cost += product.get_number("base_cost") * float(lines[product_id])
	if not economy.spend(cost, "stock order from %s" % supplier_id):
		return null

	var lead: Array = supplier.get_value("lead_time_days", [1, 2])
	var delivery := Delivery.new()
	delivery.supplier_id = supplier_id
	delivery.lines = lines.duplicate()
	delivery.cost = cost
	delivery.arrives_day = (
		_day + rng.stream(SeededRng.SPAWN).randi_range(int(lead[0]), int(lead[lead.size() - 1]))
	)

	# The cheap supplier is cheap for a reason, and the reason shows up at the back door.
	var legitimacy: Dictionary = supplier.get_value("legitimacy", {})
	var roll: float = rng.stream(SeededRng.FORGERY).randf()
	if roll < float(legitimacy.get("counterfeit_rate", 0.0)):
		delivery.problem = "counterfeit_product"
	elif roll > float(legitimacy.get("manifest_accuracy", 1.0)):
		delivery.problem = "short_shipped"

	incoming.append(delivery)
	return delivery


## Deliveries that have arrived. Accepting one is a cancellable event, so a mod — or the
## compliance system — can refuse it.
func arrivals() -> Array[Delivery]:
	var arrived: Array[Delivery] = []
	for delivery: Delivery in incoming:
		if delivery.arrives_day <= _day:
			arrived.append(delivery)
	return arrived


func accept(delivery: Delivery) -> EventOutcome:
	var outcome: EventOutcome = bus.attempt(
		EventCatalog.DELIVERY_ACCEPTED,
		{"supplier": String(delivery.supplier_id), "problem": delivery.problem}
	)
	if not outcome.allowed:
		incoming.erase(delivery)
		return outcome

	for product_id: StringName in delivery.lines.keys():
		var product: ContentDefinition = registry.get_definition(product_id)
		if product == null:
			continue
		var units: int = int(delivery.lines[product_id])
		if delivery.problem == "short_shipped":
			units = int(float(units) * 0.7)
		var shelf_life: int = int(product.get_number("shelf_life_days", 0))
		var expires: int = _day + shelf_life if shelf_life > 0 else 1_000_000
		back_room.append(
			Lot.new(product_id, units, expires, delivery.problem == "counterfeit_product")
		)
	delivery.verified = true
	incoming.erase(delivery)
	return outcome


## Move stock from the back to the shelf. Oldest first — rotation is a habit the game
## should reward without nagging about it.
func restock(product_id: StringName, units: int) -> int:
	var moved: int = 0
	var suspect_moved: int = 0
	back_room.sort_custom(func(a: Lot, b: Lot) -> bool: return a.expires_day < b.expires_day)
	for lot: Lot in back_room:
		if moved >= units:
			break
		if lot.product_id != product_id:
			continue
		var take: int = mini(lot.units, units - moved)
		lot.units -= take
		moved += take
		if lot.suspect:
			suspect_moved += take
	_prune_empty_lots()
	if moved > 0:
		shelf[product_id] = units_on_shelf(product_id) + moved
		if suspect_moved > 0:
			shelf_suspect[product_id] = suspect_units_on_shelf(product_id) + suspect_moved
	return moved


## Sells from the shelf, good stock first. A customer reaching past the front of the
## facing is not a simulation this game needs; what it does need is for the bad units to
## still be in the building afterwards, where they remain the player's problem.
func sell(product_id: StringName, units: int) -> int:
	var available: int = units_on_shelf(product_id)
	if available <= 0:
		lost_sales += units
		return 0
	var sold: int = mini(available, units)
	shelf[product_id] = available - sold
	var genuine: int = available - suspect_units_on_shelf(product_id)
	if sold > genuine:
		shelf_suspect[product_id] = suspect_units_on_shelf(product_id) - (sold - genuine)
	if sold < units:
		lost_sales += units - sold
	return sold


## Sells one unit and says whether it was one of the bad ones -- what the till knows and
## the customer does not, yet.
func sell_one(product_id: StringName) -> Dictionary:
	var available: int = units_on_shelf(product_id)
	var suspect: bool = available > 0 and suspect_units_on_shelf(product_id) >= available
	var sold: int = sell(product_id, 1)
	return {"sold": sold, "suspect": suspect}


## Takes one unit off the shelf for the shop's own use rather than a sale -- the one a
## player is about to open. Bad units come off first, because a resealed box is only ever
## discovered by somebody opening it, and the player opening it themselves is the good
## ending of that story.
func take_unit(product_id: StringName) -> Dictionary:
	if units_on_shelf(product_id) <= 0 and restock(product_id, 1) <= 0:
		return {"ok": false, "suspect": false}
	var suspect: bool = suspect_units_on_shelf(product_id) > 0
	shelf[product_id] = units_on_shelf(product_id) - 1
	if suspect:
		shelf_suspect[product_id] = suspect_units_on_shelf(product_id) - 1
	return {"ok": true, "suspect": suspect}


func suspect_units_on_shelf(product_id: StringName) -> int:
	return mini(int(shelf_suspect.get(product_id, 0)), units_on_shelf(product_id))


## Daily decay. Expired stock is destroyed and counted: spoilage is a reputation and
## inspection problem, not just a number.
func advance_day(new_day: int) -> Dictionary:
	_day = new_day
	var spoiled_now: int = 0
	for lot: Lot in back_room:
		if lot.expires_day < _day:
			spoiled_now += lot.units
			lot.units = 0
	_prune_empty_lots()
	spoiled_units += spoiled_now
	return {"spoiled": spoiled_now}


## Products whose shelf is below [param threshold]. The restock list, derived rather
## than hand-maintained.
func low_stock(threshold: int = 4) -> Array:
	var low: Array = []
	for product: ContentDefinition in registry.by_type(&"product"):
		if product.get_number("market_price") <= 0.0:
			continue  # an ingredient, not a shelf item
		if units_on_shelf(product.id) < threshold and units_in_back(product.id) > 0:
			low.append(product.id)
	return low


## What the stock in the building would fetch at shelf prices. Unsold stock is still
## worth something, and a comparison between two ways of running a shop is only honest if
## it counts it -- opening a box does not create value, it moves it from the shelf into
## the case.
func stock_value() -> float:
	var total: float = 0.0
	for product: ContentDefinition in registry.by_type(&"product"):
		var price: float = product.get_number("market_price")
		if price > 0.0:
			total += price * float(total_units(product.id))
	return total


func snapshot() -> Dictionary:
	var lots: Array = []
	for lot: Lot in back_room:
		(
			lots
			. append(
				{
					"product": String(lot.product_id),
					"units": lot.units,
					"expires": lot.expires_day,
					"suspect": lot.suspect,
				}
			)
		)
	var shelf_out: Dictionary = {}
	for product_id: StringName in shelf.keys():
		shelf_out[String(product_id)] = shelf[product_id]
	return {
		"shelf": shelf_out, "back_room": lots, "spoiled": spoiled_units, "lost_sales": lost_sales
	}


func _prune_empty_lots() -> void:
	var kept: Array[Lot] = []
	for lot: Lot in back_room:
		if lot.units > 0:
			kept.append(lot)
	back_room = kept
