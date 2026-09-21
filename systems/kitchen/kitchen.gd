class_name Kitchen
extends RefCounted

## Loop C: orders, stations, timers, and the mess that compounds under load.
##
## PlateUp is the ancestor, with one deliberate divergence: the kitchen runs at roughly
## 60-70% of that intensity, because a player also owes attention to the counter. If it
## ever consumes a player whole, its rate comes down — the collision is the point, and a
## kitchen that eats a player destroys it.

enum Station { PREP, GRIDDLE, FRYER, SLICER, COFFEE_BAR, PASS }
enum OrderState { WAITING, IN_PROGRESS, READY, SERVED, FAILED }

const MODIFIER_CLASSES: PackedStringArray = [
	"omission", "addition", "substitution", "preparation", "portioning", "quantity"
]
## Burn tolerance shrinks as surfaces foul, which is how neglect compounds.
const FOULING_PER_ORDER: float = 0.012


class Order:
	extends RefCounted
	var id: int
	var recipe_id: StringName
	var modifiers: Array[Dictionary] = []
	var table: int = 0
	var placed_tick: int = 0
	var patience_ticks: int = 0
	var state: OrderState = OrderState.WAITING
	var step_index: int = 0
	var step_started_tick: int = -1
	var accuracy: float = 1.0

	func describe() -> String:
		var parts: PackedStringArray = [String(recipe_id)]
		for modifier: Dictionary in modifiers:
			parts.append("%s:%s" % [modifier.get("class", "?"), modifier.get("value", "?")])
		return " ".join(parts)


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng
var inventory: Inventory

var orders: Array[Order] = []
var fouling: float = 0.0
var served_count: int = 0
var failed_count: int = 0
var wasted_ingredients: int = 0
var open: bool = true

var _next_id: int = 1


func _init(
	p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng, p_inventory: Inventory
) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng
	inventory = p_inventory


func available_recipes(held_licences: Array) -> Array:
	var out: Array = []
	for recipe: ContentDefinition in registry.by_type(&"recipe"):
		var required: String = recipe.get_text("unlocked_by", "")
		if required.is_empty() or held_licences.has(StringName(required)):
			out.append(recipe)
	return out


## Takes an order, generating modifiers from the grammar. 45 recipes crossed with these
## produce thousands of distinct orders — which is where the memory pressure comes from.
func take_order(recipe: ContentDefinition, table: int, tick: int, patience_ticks: int) -> Order:
	var order := Order.new()
	order.id = _next_id
	_next_id += 1
	order.recipe_id = recipe.id
	order.table = table
	order.placed_tick = tick
	order.patience_ticks = patience_ticks

	var allowed: Array = recipe.get_value("modifiers_allowed", [])
	var modifier_count: int = rng.stream(SeededRng.SPAWN).randi_range(0, mini(2, allowed.size()))
	for _index: int in range(modifier_count):
		var modifier_class: String = str(rng.pick(SeededRng.SPAWN, allowed))
		order.modifiers.append(
			{"class": modifier_class, "value": _modifier_value(modifier_class, recipe)}
		)

	orders.append(order)
	bus.publish(
		EventCatalog.ORDER_TAKEN,
		{
			"order": order.id,
			"recipe": String(recipe.id),
			"table": table,
			"modifiers": order.modifiers.size()
		}
	)
	return order


## Starts the next step, consuming ingredients from the floor's stock. Running out is a
## floor failure that lands on the kitchen, which is exactly the intended coupling.
func start_order(order: Order, tick: int) -> bool:
	var recipe: ContentDefinition = registry.get_definition(order.recipe_id)
	if recipe == null:
		return false
	if order.state == OrderState.WAITING:
		for ingredient: Dictionary in recipe.get_value("ingredients", []):
			if bool(ingredient.get("optional", false)):
				continue
			var product_id := StringName(str(ingredient.get("product", "")))
			if inventory.total_units(product_id) <= 0:
				order.state = OrderState.FAILED
				failed_count += 1
				bus.publish(
					EventCatalog.ORDER_FAILED,
					{"order": order.id, "reason": "out of %s" % product_id}
				)
				return false
			inventory.restock(product_id, 1)
			inventory.sell(product_id, 1)
	order.state = OrderState.IN_PROGRESS
	order.step_started_tick = tick
	return true


## One tick of cooking. Steps have real timers and a tolerance that fouling erodes;
## overrun far enough and the food is burnt rather than merely late.
func tick(current_tick: int) -> void:
	for order: Order in orders:
		if order.state == OrderState.IN_PROGRESS:
			_advance_order(order, current_tick)
		elif (
			order.state == OrderState.WAITING
			and current_tick - order.placed_tick > order.patience_ticks
		):
			order.state = OrderState.FAILED
			failed_count += 1
			bus.publish(
				EventCatalog.ORDER_FAILED, {"order": order.id, "reason": "walked out waiting"}
			)
	_prune()


func _advance_order(order: Order, current_tick: int) -> void:
	var recipe: ContentDefinition = registry.get_definition(order.recipe_id)
	var steps: Array = recipe.get_value("steps", [])
	if order.step_index >= steps.size():
		order.state = OrderState.READY
		return

	var step: Dictionary = steps[order.step_index]
	var seconds: float = float(step.get("seconds", 5.0))
	var tolerance: float = float(step.get("tolerance", 3.0)) * maxf(0.2, 1.0 - fouling)
	var elapsed: float = (
		float(current_tick - order.step_started_tick) * TickScheduler.SECONDS_PER_TICK
	)

	if elapsed < seconds:
		return
	if elapsed > seconds + tolerance:
		# Burnt. Accuracy drops rather than failing outright: a bad sandwich still goes
		# out, and the complaint arrives later.
		order.accuracy = maxf(0.0, order.accuracy - 0.35)
		wasted_ingredients += 1
	order.step_index += 1
	order.step_started_tick = current_tick
	if order.step_index >= steps.size():
		order.state = OrderState.READY


## Hands an order over. Accuracy is scored against the full order including modifiers,
## which is what the ticket printer unlock is really buying you.
func serve(order: Order, economy: Economy, remembered_modifiers: int = -1) -> Dictionary:
	var recipe: ContentDefinition = registry.get_definition(order.recipe_id)
	if order.state != OrderState.READY:
		return {"served": false, "reason": "not ready"}

	var expected: int = order.modifiers.size()
	var remembered: int = expected if remembered_modifiers < 0 else remembered_modifiers
	if remembered < expected:
		order.accuracy = maxf(0.0, order.accuracy - 0.3 * float(expected - remembered))

	var price: float = recipe.get_number("price")
	var paid: float = price * clampf(order.accuracy, 0.0, 1.0)
	economy.earn(paid, "kitchen: %s" % order.recipe_id)
	order.state = OrderState.SERVED
	served_count += 1
	fouling = clampf(fouling + FOULING_PER_ORDER, 0.0, 1.0)

	var result: Dictionary = {
		"served": true,
		"order": order.id,
		"recipe": String(order.recipe_id),
		"accuracy": order.accuracy,
		"paid": paid,
	}
	bus.publish(EventCatalog.ORDER_COMPLETED, result)
	return result


## Scraping, oil changes, wiping. Neglect raises burn rates and slows every later step,
## so cleaning down is time spent to buy time back.
func clean_down(seconds: float) -> void:
	fouling = clampf(fouling - seconds * 0.004, 0.0, 1.0)


func pending_orders() -> Array[Order]:
	var out: Array[Order] = []
	for order: Order in orders:
		if order.state in [OrderState.WAITING, OrderState.IN_PROGRESS, OrderState.READY]:
			out.append(order)
	return out


func stats() -> Dictionary:
	return {
		"served": served_count,
		"failed": failed_count,
		"pending": pending_orders().size(),
		"fouling": fouling,
		"wasted": wasted_ingredients,
	}


func _modifier_value(modifier_class: String, recipe: ContentDefinition) -> String:
	match modifier_class:
		"omission":
			var ingredients: Array = recipe.get_value("ingredients", [])
			if ingredients.is_empty():
				return "no extras"
			return (
				"no %s"
				% str((ingredients[ingredients.size() - 1] as Dictionary).get("product", "extras"))
			)
		"addition":
			return "extra cheese"
		"substitution":
			return "oat milk"
		"preparation":
			return str(rng.pick(SeededRng.SPAWN, ["toasted", "well done", "extra hot", "light"]))
		"portioning":
			return "cut in half"
		_:
			return "make it two"


func _prune() -> void:
	var kept: Array[Order] = []
	for order: Order in orders:
		if order.state in [OrderState.WAITING, OrderState.IN_PROGRESS, OrderState.READY]:
			kept.append(order)
	orders = kept
