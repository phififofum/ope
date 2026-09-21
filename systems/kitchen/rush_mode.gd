class_name RushMode
extends RefCounted

## The kitchen alone, escalating until the queue overruns you.
##
## A twenty-five minute co-op session for a night when nobody wants a campaign, and the
## natural home for seeded challenges and leaderboards. It costs very little to build
## because it is the whole of Loop C with a different director profile and no shop --
## which is also the clearest evidence that the systems really are separable.

const DAY_TICKS: int = 90 * TickScheduler.TICKS_PER_SECOND  ## a short, sharp day
const UPGRADE_CHOICES: int = 3


class Run:
	extends RefCounted
	var day: int = 0
	var served: int = 0
	var failed: int = 0
	var upgrades: PackedStringArray = []
	var ended_because: String = ""

	func summary() -> Dictionary:
		return {
			"days_survived": day,
			"served": served,
			"failed": failed,
			"upgrades": upgrades,
			"ended_because": ended_because,
		}


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng
var kitchen: Kitchen
var inventory: Inventory
var economy: Economy
var clock := TickScheduler.new()
var run := Run.new()

var _order_interval: int = 220


func _init(p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng
	economy = Economy.new(bus)
	inventory = Inventory.new(registry, bus)
	kitchen = Kitchen.new(registry, bus, rng, inventory)
	# A fixed small kitchen, fully stocked: this mode is about the machine you build out
	# of layout and muscle memory, not about supply.
	for product: ContentDefinition in registry.by_type(&"product"):
		inventory.back_room.append(Inventory.Lot.new(product.id, 9999, 1_000_000))
		inventory.restock(product.id, 400)


## One day. Returns false when the queue has overrun you, which is a wall rather than a
## fail state: it tells you what to rebuild.
func play_day(serve_policy: Callable) -> bool:
	run.day += 1
	# Each day raises the rate against the same physical space.
	_order_interval = maxi(45, 220 - run.day * 12)
	var recipes: Array = kitchen.available_recipes([&"base:general_retail", &"base:food_service"])
	if recipes.is_empty():
		run.ended_because = "no recipes available"
		return false

	for tick_index: int in range(DAY_TICKS):
		clock.advance_ticks(1)
		var now: int = clock.current_tick()
		if tick_index % _order_interval == 0:
			kitchen.take_order(rng.pick(SeededRng.SPAWN, recipes), tick_index % 8, now, 900)
		kitchen.tick(now)
		serve_policy.call(kitchen, now)

		if kitchen.pending_orders().size() > 12:
			run.ended_because = "the queue never cleared"
			run.served = int(kitchen.stats()["served"])
			run.failed = int(kitchen.stats()["failed"])
			return false

	run.served = int(kitchen.stats()["served"])
	run.failed = int(kitchen.stats()["failed"])
	return true


## Between days you pick one of three, and layout changes are free. Each removes exactly
## one manual step -- never the whole job.
func offer_upgrades() -> Array:
	var pool: Array = []
	for upgrade: ContentDefinition in registry.by_type(&"upgrade"):
		if upgrade.get_text("category") != "automation":
			continue
		if run.upgrades.has(String(upgrade.id)):
			continue
		pool.append(upgrade)
	var offered: Array = []
	for _index: int in range(mini(UPGRADE_CHOICES, pool.size())):
		var pick: ContentDefinition = rng.pick(SeededRng.SPAWN, pool)
		if pick != null and not offered.has(pick):
			offered.append(pick)
	return offered


func take_upgrade(upgrade: ContentDefinition) -> void:
	run.upgrades.append(String(upgrade.id))
	# Automation buys back seconds, which is the only currency this mode has.
	kitchen.clean_down(20.0)
	_order_interval += 8
