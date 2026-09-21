class_name Shop
extends RefCounted

## The shift: every loop running against the same clock and the same pairs of hands.
##
## This is where the design's central claim becomes mechanical. A shift generates more
## work than there is time to do it, every task costs seconds, and the player spends those
## seconds somewhere. Scrutiny is a budget, and this class is the budget.
##
## It is driven entirely by ticks, so a human at 60fps, five networked peers and the bot
## player running a day in two seconds all execute the same simulation.

enum Task {
	IDLE,
	SERVE_COUNTER,
	COOK,
	RUN_FOOD,
	CHECK_RETURN,
	RESTOCK,
	CLEAN,
	RECEIVE_DELIVERY,
	CAT_CARE,
	CASE_WORK,
	RIP_SEALED,
	AUDIT,
}

const DAY_TICKS: int = 25 * 60 * TickScheduler.TICKS_PER_SECOND  ## ~25 real minutes
const SHIFTS: PackedStringArray = [
	"morning", "midday", "afternoon", "evening", "event_night", "late_night", "dead_hours"
]
const RENT_PER_DAY: float = 210.0
const UTILITIES_PER_DAY: float = 68.0


class PlayerSlot:
	extends RefCounted
	var index: int
	var busy_until: int = 0
	var task: Task = Task.IDLE
	var seconds_spent: Dictionary = {}

	func is_free(tick: int) -> bool:
		return tick >= busy_until

	func occupy(tick: int, seconds: float, new_task: Task) -> void:
		busy_until = tick + maxi(1, int(seconds * float(TickScheduler.TICKS_PER_SECOND)))
		task = new_task
		seconds_spent[new_task] = float(seconds_spent.get(new_task, 0.0)) + seconds


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng
var clock := TickScheduler.new()

var economy: Economy
var inventory: Inventory
var library: GameLibrary
var maintenance: Maintenance
var kitchen: Kitchen
var card_case: CardCase
var cats: CatSystem
var staff: StaffSystem
var director: Director
var verification: VerificationEngine
var people: PersonFactory

var players: Array[PlayerSlot] = []
var day: int = 1
var shift_index: int = 0
var owned_tools: PackedStringArray = ["base:naked_eye", "base:date_wheel"]
## The glass you inherited. Everything past it is bought.
var owned_fixtures: PackedStringArray = ["base:display_case"]

## Work waiting for a pair of hands. The queue is the game.
var waiting_encounters: Array[Encounter] = []
var served_today: int = 0
var walked_out: int = 0
var customers_in_room: int = 0
## Sealed units that went out of the door with the hits already missing. The customer
## finds out at home, and it comes back as reputation a day or two later.
var pending_sealed_complaints: Array[int] = []

var _day_start_tick: int = 0
var _last_sample_tick: int = 0
## The range the shop may legally sell, rebuilt each morning.
var _sellable: Array = []


func _init(
	p_registry: ContentRegistry,
	p_bus: EventBus,
	p_rng: SeededRng,
	profile: Director.Profile,
	player_count: int = 3
) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng

	economy = Economy.new(bus)
	inventory = Inventory.new(registry, bus)
	library = GameLibrary.new(registry, bus, rng)
	maintenance = Maintenance.new(bus, rng)
	kitchen = Kitchen.new(registry, bus, rng, inventory)
	card_case = CardCase.new(registry, bus, rng)
	cats = CatSystem.new(registry, bus, rng)
	staff = StaffSystem.new(registry, bus, rng)
	director = Director.new(profile, rng)
	verification = VerificationEngine.new(registry, bus, rng)
	people = PersonFactory.new(rng, day, registry)

	for index: int in range(maxi(1, player_count)):
		var slot := PlayerSlot.new()
		slot.index = index
		players.append(slot)

	# You inherited the place, and it came with a kitchen and the paperwork to run it.
	# Everything beyond these two is a decision with a cost attached.
	economy.grant_licence(&"base:general_retail")
	economy.grant_licence(&"base:food_service")


## Stocks the opening shop: a starting range, a few library copies, one cat's worth of
## pest pressure to come. Deliberately thin — the opening exists to be tight.
func open_for_business(starting_float: float = 0.0) -> void:
	if starting_float > 0.0:
		economy.earn(starting_float, "opening float")
	for product: ContentDefinition in registry.by_type(&"product"):
		if product.get_number("market_price") <= 0.0:
			inventory.back_room.append(Inventory.Lot.new(product.id, 20, day + 60))
			continue
		# Sealed product is capital tied up in cardboard, so the opening shop gets a
		# thin rack of it and has to decide what to do with each unit.
		var units: int = 3 if _is_sealed_product(product) else 12
		inventory.back_room.append(Inventory.Lot.new(product.id, units, day + 30))
		inventory.restock(product.id, maxi(1, units / 2))
	var games: Array = registry.by_type(&"board_game")
	for index: int in range(mini(40, games.size())):
		library.acquire((games[index] as ContentDefinition).id, 1)


## Which act the campaign is in. Each one asks a different question, and the director
## and the content both read it: Act IV is when adversaries start probing the tools you
## do not have.
func act() -> int:
	if day <= 14:
		return 1
	if day <= 42:
		return 2
	if day <= 84:
		return 3
	if day <= 140:
		return 4
	return 5


func act_question() -> String:
	match act():
		1:
			return "Can you keep the lights on?"
		2:
			return "Can you grow without losing control of quality?"
		3:
			return "Can you run four loops at once?"
		4:
			return "Adaptive adversaries, organised fraud, and the grey-market offer."
		_:
			return "Seeded runs, leaderboards, and the shop you built."


## Interviews and hires. Hiring is itself a verification encounter: a work history you
## can check, references you can call, and credentials that may be fabricated.
func interview(role_id: StringName) -> StaffSystem.Employee:
	return staff.generate_applicant(role_id)


func hire(employee: StaffSystem.Employee, slot: PlayerSlot, now: int) -> Dictionary:
	slot.occupy(now, 90.0, Task.AUDIT)
	var outcome: EventOutcome = staff.hire(employee, economy)
	return {
		"hired": outcome.allowed,
		"reason": outcome.reason,
		"lied": employee.lied_on_application(),
	}


## Buys a licence. Each one unlocks categories and adds verification burden -- the more
## you are permitted to sell, the more there is to get wrong.
## The best tier of tool in the player's hands. It is the ceiling on forgery difficulty,
## which is how the tool tree and the difficulty curve stay the same curve.
func toolkit_tier() -> int:
	var best: int = 0
	for tool_id: String in owned_tools:
		var tool: ContentDefinition = registry.get_definition(StringName(tool_id))
		if tool != null:
			best = maxi(best, int(tool.get_number("tier", 0)))
	return best


## Tools unlock from the progression state rather than from a shopping list: a licence
## you took, a reputation tier you reached, a room you built. Every tool is also a
## physical object in the world, so acquiring one is a change to the counter, not a
## checkbox.
func refresh_unlocked_tools() -> PackedStringArray:
	var gained: PackedStringArray = []
	for tool: ContentDefinition in registry.by_type(&"tool"):
		var tool_id: String = String(tool.id)
		if owned_tools.has(tool_id):
			continue
		if _unlock_condition_met(tool.get_text("unlocked_by", "")):
			owned_tools.append(tool_id)
			gained.append(tool_id)
	return gained


func _unlock_condition_met(condition: String) -> bool:
	if condition.is_empty() or condition == "start":
		return true
	if condition.begins_with("base:"):
		return economy.holds(StringName(condition))
	match condition:
		"reputation_tier_2":
			return economy.reputation >= 2.0
		"store_level_3":
			return economy.standing >= 3
		"back_office":
			return economy.standing >= 4 and economy.money > 2500.0
		"licence_tier_3":
			return economy.standing >= 3
		"cash handling upgrade", "cash volume milestone":
			return economy.money > 3000.0
		"supplier trust tier 2":
			return day > 10
		"late_campaign":
			return day > 40
		"adoption, bonded":
			return not cats.residents.is_empty()
	return false


func buy_licence(licence_id: StringName) -> bool:
	var licence: ContentDefinition = registry.get_definition(licence_id)
	if licence == null or economy.holds(licence_id):
		return false
	if economy.standing < int(licence.get_number("standing_required", 0)):
		return false
	if not economy.spend(licence.get_number("cost"), "licence: %s" % licence_id):
		return false
	economy.grant_licence(licence_id)
	_refresh_sellable_range()
	return true


## Licences the shop could take right now, cheapest first. Taking one is not always
## correct: an easier shift is a real, occasionally right choice.
func affordable_licences() -> Array:
	var out: Array = []
	for licence: ContentDefinition in registry.by_type(&"licence"):
		if economy.holds(licence.id):
			continue
		if economy.standing < int(licence.get_number("standing_required", 0)):
			continue
		# Keep a float: a licence that empties the till before the evening rush is how
		# the opening week teaches its lesson, and the bot should not fall for it.
		if licence.get_number("cost") <= economy.money - 500.0:
			out.append(licence)
	out.sort_custom(
		func(a: ContentDefinition, b: ContentDefinition) -> bool:
			return a.get_number("cost") < b.get_number("cost")
	)
	return out


func start_day(new_day: int) -> void:
	day = new_day
	shift_index = 0
	served_today = 0
	walked_out = 0
	_day_start_tick = clock.current_tick()
	inventory.set_day(day)
	card_case.set_day(day)
	staff.set_day(day)
	people.set_today(day)
	verification.set_today(day)
	economy.advance_day(day)
	refresh_unlocked_tools()
	people.admit_named_cast(day)
	_refresh_sellable_range()
	director.plan_shift(DAY_TICKS, players.size())
	bus.publish(EventCatalog.SHIFT_STARTED, {"day": day, "shift": SHIFTS[0]})


## One simulation tick: the world moves whether or not anybody is looking at it.
func tick() -> void:
	clock.advance_ticks(1)
	var now: int = clock.current_tick()
	var elapsed: int = now - _day_start_tick
	shift_index = clampi(
		int(float(elapsed) / float(DAY_TICKS) * float(SHIFTS.size())), 0, SHIFTS.size() - 1
	)

	if director.should_spawn(
		now,
		players.size(),
		waiting_encounters.size() + kitchen.pending_orders().size(),
		card_case.display_draw()
	):
		_spawn_customer(now)
	elif director.should_prod(now):
		_spawn_customer(now)

	kitchen.tick(now)
	maintenance.tick(served_today, int(kitchen.stats()["served"]), cats.hunting_pressure())

	# Sessions end and games come back to the counter, where they join the queue of
	# things that want checking.
	for copy: GameLibrary.Copy in library.due_back(now):
		library.return_copy(
			copy, float(now - copy.loaned_tick) * TickScheduler.SECONDS_PER_TICK / 3600.0
		)

	for encounter: Encounter in waiting_encounters.duplicate():
		var waited: int = now - encounter.opened_tick
		if waited > int(600.0 * encounter.person.patience):
			waiting_encounters.erase(encounter)
			walked_out += 1
			bus.publish(
				EventCatalog.CUSTOMER_LEFT,
				{"person": String(encounter.person.id), "reason": "queue too long"}
			)


## Closes the day: costs, spoilage, market drift, staff, strikes. The morning-after
## reconciliation is the densest audit in the game and it starts here.
func end_day() -> Dictionary:
	var spoilage: Dictionary = inventory.advance_day(day + 1)
	card_case.advance_day(day + 1)
	cats.advance_day(day + 1)
	var staff_result: Dictionary = staff.advance_day(day + 1, economy)
	var shift_pressure: float = clampf(float(walked_out) / maxf(1.0, float(served_today)), 0.0, 1.0)
	var shift_work: Dictionary = staff.work_shift(shift_pressure, economy)

	economy.pay_costs(RENT_PER_DAY, float(shift_work["wages"]), UTILITIES_PER_DAY)
	if int(spoilage["spoiled"]) > 0:
		economy.adjust_reputation(-0.05 * float(spoilage["spoiled"]) * 0.1, "spoilage")
	economy.adjust_reputation(cats.customer_appeal() * 0.02, "the cat")
	# The wall pays in footfall, and only while there is something on it worth the walk.
	card_case.showcase_capacity = _showcase_capacity()
	economy.adjust_reputation(card_case.display_draw() * 0.03, "the display case")
	var complaints: int = 0
	for due_day: int in pending_sealed_complaints.duplicate():
		if due_day > day:
			continue
		pending_sealed_complaints.erase(due_day)
		complaints += 1
		economy.adjust_reputation(-0.25, "sold a box somebody had already opened")
	economy.adjust_reputation((maintenance.cleanliness - 0.6) * 0.1, "cleanliness")

	var stolen: Array = card_case.apply_shrink(_counter_sightline())
	var summary: Dictionary = {
		"day": day,
		"served": served_today,
		"walked_out": walked_out,
		"money": economy.money,
		"reputation": economy.reputation,
		"spoiled": spoilage["spoiled"],
		"kitchen": kitchen.stats(),
		"library": library.stats(),
		"case_value": card_case.case_value(),
		"stock_value": inventory.stock_value(),
		"stolen_singles": stolen.size(),
		"sealed": card_case.sealed_ledger(),
		"display_draw": card_case.display_draw(),
		"sealed_complaints": complaints,
		"staff": staff_result,
		"cleanliness": maintenance.cleanliness,
		"pests": maintenance.pest_pressure,
	}
	bus.publish(EventCatalog.DAY_ENDED, summary)
	bus.publish(EventCatalog.SHIFT_ENDED, {"day": day})
	return summary


# --- What a player can do with their hands --------------------------------------


func free_players(now: int) -> Array[PlayerSlot]:
	var free: Array[PlayerSlot] = []
	for slot: PlayerSlot in players:
		if slot.is_free(now):
			free.append(slot)
	return free


## Serve the next person at the counter. [param tools_used] is what the player actually
## reached for, and it costs the seconds it costs.
func serve_counter(
	slot: PlayerSlot,
	verdict: Encounter.Verdict,
	tools_used: PackedStringArray,
	now: int,
	reason: String = ""
) -> Dictionary:
	if waiting_encounters.is_empty():
		return {}
	var encounter: Encounter = waiting_encounters.pop_front()
	var seconds: float = 4.0 + verification.inspection_cost(tools_used)
	slot.occupy(now, seconds, Task.SERVE_COUNTER)

	var result: Dictionary = verification.resolve(
		encounter, verdict, tools_used, now, owned_tools, reason
	)
	director.record_outcome(int(result["outcome"]) == Encounter.Outcome.CORRECT)
	economy.adjust_reputation(float(result["reputation_delta"]), "verdict")
	people.record_transaction(encounter.person, int(result["outcome"]) == Encounter.Outcome.CORRECT)

	if verdict == Encounter.Verdict.APPROVE:
		var sale: EventOutcome = (
			bus
			. attempt(
				EventCatalog.SALE_ATTEMPTED,
				{
					"age_restricted": encounter.transaction_tags.has("age_restricted"),
					"id_verified": tools_used.size() > 0,
					"value": encounter.value,
				}
			)
		)
		if sale.allowed:
			# Reputation is built by ordinary competence, a little at a time, and lost
			# in single expensive moments. That asymmetry is the whole feel of it.
			#
			# Competence, though -- not luck. Waving somebody through without looking at
			# the thing they put on the counter is not the ordinary good work this pays
			# for, and paying for it would make volume beat judgement.
			if not encounter.has_unchecked_rule():
				economy.adjust_reputation(0.012, "served well")
			if encounter.value < 0.0:
				# A trade-in: cash leaves the till and a card enters the case. Whether
				# that was a good trade depends on an assessment the player already made.
				_take_trade_in(encounter, absf(encounter.value))
			else:
				economy.earn(encounter.value, "counter sale")
			served_today += 1
			bus.publish(
				EventCatalog.CUSTOMER_SERVED,
				{"person": String(encounter.person.id), "value": encounter.value}
			)
		else:
			result["vetoed"] = sale.reason
	# Approving something that should have been refused earns a strike, and the fine
	# arrives whether or not anybody noticed at the time.
	if int(result["outcome"]) == Encounter.Outcome.WRONG_APPROVED:
		economy.issue_strike(&"base:general_retail", "approved a bad transaction")
	return result


func cook_next(slot: PlayerSlot, now: int) -> bool:
	for order: Kitchen.Order in kitchen.pending_orders():
		if order.state == Kitchen.OrderState.WAITING:
			if kitchen.start_order(order, now):
				slot.occupy(now, 6.0, Task.COOK)
				return true
			return false
	return false


func run_food(slot: PlayerSlot, now: int) -> bool:
	for order: Kitchen.Order in kitchen.pending_orders():
		if order.state == Kitchen.OrderState.READY:
			var result: Dictionary = kitchen.serve(order, economy)
			# An accurate order is worth something; a wrong one is remembered.
			var accuracy: float = float(result.get("accuracy", 1.0))
			economy.adjust_reputation((accuracy - 0.6) * 0.05, "kitchen accuracy")
			# Table service means travel: the plate goes to a specific table, through the
			# floor plan you designed.
			slot.occupy(now, 8.0, Task.RUN_FOOD)
			served_today += 1
			return true
	return false


func check_next_return(slot: PlayerSlot, now: int) -> Dictionary:
	if library.awaiting_check.is_empty():
		return {}
	var copy: GameLibrary.Copy = library.awaiting_check[0]
	var seconds: float = library.check_seconds(copy)
	slot.occupy(now, seconds, Task.CHECK_RETURN)
	var result: Dictionary = library.perform_check(copy)
	# A complete copy going back on the shelf is quiet, ordinary competence. An
	# incomplete one found now is a problem you caught instead of one you lent out.
	economy.adjust_reputation(
		0.02 if bool(result.get("complete", true)) else 0.01, "component check"
	)
	return result


func restock_shelves(slot: PlayerSlot, now: int) -> int:
	var restocked: int = 0
	for product_id: StringName in inventory.low_stock():
		restocked += inventory.restock(product_id, 6)
		if restocked > 0:
			break
	if restocked > 0:
		slot.occupy(now, 12.0, Task.RESTOCK)
	return restocked


func clean_up(slot: PlayerSlot, now: int, seconds: float = 20.0) -> void:
	slot.occupy(now, seconds, Task.CLEAN)
	maintenance.clean(seconds)
	if maintenance.tables_dirty > 0:
		maintenance.reset_table()
	if maintenance.waste_units > 30.0:
		maintenance.empty_bins()


func receive_deliveries(slot: PlayerSlot, now: int, verify: bool) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for delivery: Inventory.Delivery in inventory.arrivals():
		# Verifying a delivery properly costs a minute you do not have, which is why a
		# trio usually waves them through and a fourth player changes the game.
		var seconds: float = 45.0 if verify else 8.0
		slot.occupy(now, seconds, Task.RECEIVE_DELIVERY)
		var caught: bool = verify and not delivery.problem.is_empty()
		if caught:
			inventory.incoming.erase(delivery)
		else:
			inventory.accept(delivery)
		results.append(
			{
				"supplier": String(delivery.supplier_id),
				"problem": delivery.problem,
				"caught": caught
			}
		)
	return results


func tend_cats(slot: PlayerSlot, now: int) -> void:
	slot.occupy(now, 15.0, Task.CAT_CARE)
	for cat: CatSystem.Cat in cats.residents:
		if cat.outside:
			cats.recover_cat(cat)
		cats.feed(cat, inventory)
		cats.play_with(cat, "player_%d" % slot.index)
	if cats.stray_present:
		cats.feed_stray()


## Pricing the case, collecting grading, and deciding what goes on the wall. Money in
## cardboard is money not in coffee, so the case has to be worked rather than admired.
##
## The two thresholds are the whole decision. A single worth more than [param
## display_above] goes behind glass, where it earns footfall instead of cash; one worth
## more than [param sell_above] goes out of the door for money. Display is checked first,
## because the card you would most like to sell is the card people came in to see.
func work_the_case(
	slot: PlayerSlot, now: int, sell_above: float = 0.0, display_above: float = 0.0
) -> Dictionary:
	slot.occupy(now, 25.0, Task.CASE_WORK)
	var graded: Array[Dictionary] = card_case.collect_grading(economy)
	card_case.showcase_capacity = _showcase_capacity()
	var displayed: int = 0
	if display_above > 0.0:
		for single: CardCase.Single in _by_value_descending(card_case.stock):
			if card_case.current_value(single) < display_above:
				break
			if not card_case.put_on_display(single):
				break
			displayed += 1
	var sold: int = 0
	var takings: float = 0.0
	if sell_above > 0.0:
		for single: CardCase.Single in card_case.stock.duplicate():
			if card_case.current_value(single) >= sell_above:
				takings += card_case.sell_single(single, economy)
				sold += 1
				if sold >= 4:
					break
	return {
		"graded": graded.size(),
		"sold": sold,
		"displayed": displayed,
		"takings": takings,
		"case_value": card_case.case_value(),
		"draw": card_case.display_draw(),
	}


## Opens a sealed unit the shop owns. The ceremony is the point and it costs the seconds
## it costs: a box is most of a minute you were not spending on the queue.
##
## This is the only action in the game whose payoff is a distribution rather than a
## consequence of judgement, and it is deliberately measured against the sale you gave up
## -- see [method CardCase.sealed_ledger].
func rip_sealed(slot: PlayerSlot, now: int, product_id: StringName) -> Dictionary:
	var product: ContentDefinition = registry.get_definition(product_id)
	if product == null or not _is_sealed_product(product):
		return {"opened": false, "reason": "not sealed product"}
	var packs: int = maxi(1, int(product.get_value("sealed", {}).get("packs", 1)))
	slot.occupy(now, clampf(5.0 + float(packs) * 1.6, 5.0, 70.0), Task.RIP_SEALED)

	var result: Dictionary = card_case.rip(product_id, inventory, economy)
	if not bool(result.get("opened", false)):
		return result
	# A card worth looking at is a reason to come back, and word travels. A box somebody
	# else already opened is a quiet, expensive lesson about where you buy your stock.
	if float(result.get("best_value", 0.0)) >= 60.0:
		economy.adjust_reputation(0.03, "a hit pulled in the shop")
	elif bool(result.get("resealed", false)):
		economy.adjust_reputation(-0.02, "a resealed box")
	return result


## Sealed units the shop is licensed to sell and has in the building. The rip-or-sell
## decision needs a list, and the list is a registry query so a mod's set turns up in it.
func sellable_sealed() -> Array:
	var out: Array = []
	for product: ContentDefinition in _sellable:
		if _is_sealed_product(product) and inventory.total_units(product.id) > 0:
			out.append(product)
	return out


func _is_sealed_product(product: ContentDefinition) -> bool:
	return not product.get_value("sealed", {}).is_empty()


## How many cards the wall can hold, which is a fixture decision rather than a number in
## code: buy a bigger case and you can show more of what you pulled.
func _showcase_capacity() -> int:
	var slots: int = 2
	for fixture_id: String in owned_fixtures:
		var fixture: ContentDefinition = registry.get_definition(StringName(fixture_id))
		if fixture != null and fixture.get_text("category") == "case":
			slots += int(fixture.get_number("capacity", 0)) / 16
	return clampi(slots, 2, 24)


## Buys a fixture outright. Glass is capital like anything else: a bigger case shows more
## and is one more thing that was not stock.
func buy_fixture(fixture_id: StringName) -> bool:
	var fixture: ContentDefinition = registry.get_definition(fixture_id)
	if fixture == null or owned_fixtures.has(String(fixture_id)):
		return false
	if not economy.spend(fixture.get_number("cost"), "fixture: %s" % fixture_id):
		return false
	owned_fixtures.append(String(fixture_id))
	card_case.showcase_capacity = _showcase_capacity()
	return true


func audit_staff(slot: PlayerSlot, now: int, thoroughness: float = 0.6) -> Array:
	slot.occupy(now, 60.0, Task.AUDIT)
	return staff.review("review", thoroughness)


func pressure() -> float:
	var work: int = (
		waiting_encounters.size()
		+ kitchen.pending_orders().size()
		+ library.awaiting_check.size()
		+ maintenance.tables_dirty
	)
	return clampf(float(work) / float(maxi(1, players.size()) * 3), 0.0, 3.0)


func state_sample() -> Dictionary:
	return {
		"money": economy.money,
		"reputation": economy.reputation,
		"queue": waiting_encounters.size(),
		"orders": kitchen.pending_orders().size(),
		"awaiting_check": library.awaiting_check.size(),
		"cleanliness": maintenance.cleanliness,
		"pests": maintenance.pest_pressure,
		"pressure": pressure(),
		"served": served_today,
	}


## One walk-up retail sale. Nothing to verify unless the licence says so -- this is Loop
## A, where the only question is whether the thing they wanted was faced and in stock.
func _sell_from_shelf(person: Person) -> bool:
	if _sellable.is_empty():
		return false
	# Faced stock changes all day; the licensed range does not. So the range is cached
	# and the shelf is checked at the moment somebody reaches for it.
	var product: ContentDefinition = rng.pick(SeededRng.SPAWN, _sellable)
	var sale: Dictionary = inventory.sell_one(product.id)
	if int(sale["sold"]) <= 0:
		return false

	var price: float = bus.query(
		EventCatalog.PRICE_REQUESTED,
		{"product": String(product.id), "person": String(person.id)},
		product.get_number("market_price")
	)
	economy.earn(price, "shelf sale: %s" % product.id)
	served_today += 1
	if _is_sealed_product(product):
		card_case.record_sealed_sale(price)
		if bool(sale["suspect"]):
			# They will open it tonight. What comes back is not a refund request, it is
			# a story about your shop told to everyone who plays here.
			pending_sealed_complaints.append(day + 2)
	bus.publish(EventCatalog.CUSTOMER_SERVED, {"person": String(person.id), "value": price})
	return true


## What the licences in the safe allow the shop to put a price on. Rebuilt each morning
## and whenever a licence is bought, because the range changes about once a week and the
## shelf changes several times a minute.
func _refresh_sellable_range() -> void:
	_sellable = []
	for product: ContentDefinition in registry.by_type(&"product"):
		if product.get_number("market_price") <= 0.0:
			continue
		if economy.holds(StringName(product.get_text("licence"))):
			_sellable.append(product)


func _by_value_descending(singles: Array[CardCase.Single]) -> Array:
	var sorted_singles: Array = singles.duplicate()
	sorted_singles.sort_custom(
		func(a: CardCase.Single, b: CardCase.Single) -> bool:
			return card_case.current_value(a) > card_case.current_value(b)
	)
	return sorted_singles


func _counter_sightline() -> float:
	# What the counter cannot see is shrink exposure. A busier room sees less.
	return clampf(0.85 - float(customers_in_room) * 0.02, 0.2, 0.95)


func _spawn_customer(now: int) -> void:
	var person: Person = people.next_customer()
	customers_in_room = mini(customers_in_room + 1, 40)

	var roll: float = rng.stream(SeededRng.SPAWN).randf()

	if roll < 0.28 and not kitchen_closed():
		var recipes: Array = kitchen.available_recipes(economy.licences.keys())
		if not recipes.is_empty():
			var recipe: ContentDefinition = rng.pick(SeededRng.SPAWN, recipes)
			kitchen.take_order(recipe, customers_in_room % 12, now, int(900.0 * person.patience))
			return
	# Somebody who just wants to buy something off the shelf. Most of a shop's day is
	# this, and it is the other half of the sealed decision: every pack on the rack is a
	# pack a customer could have bought, which is what makes opening one cost something.
	if roll < 0.5 and _sell_from_shelf(person):
		return
	if roll < 0.62:
		var lendable: Array = library.lendable()
		if not lendable.is_empty():
			var copy: GameLibrary.Copy = rng.pick(SeededRng.SPAWN, lendable)
			var session_ticks: int = rng.stream(SeededRng.SPAWN).randi_range(3600, 21600)
			library.lend(copy, person.id, now, session_ticks)
			economy.earn(4.5, "table time")
			return

	# Which artifact lands on the counter is a registry query, not a list of ids in
	# code: every document type the content ships -- and every one a mod adds -- turns
	# up here without this function knowing about it.
	var family: String = "identity"
	var tags := PackedStringArray(["id_required", "age_restricted"])
	var value: float = rng.stream(SeededRng.SPAWN).randf_range(4.0, 26.0)
	if roll > 0.9:
		family = "collectible"
		tags = PackedStringArray(["authentication", "trade_in"])
		value = -rng.stream(SeededRng.SPAWN).randf_range(15.0, 240.0)
	elif roll > 0.82:
		family = "commercial"
		# A trade-in is a purchase, not a resale: the holding period restricts when you
		# may sell the thing on, and applying it at the buy counter refuses every honest
		# seller who walks in.
		tags = PackedStringArray(["trade_in", "id_required"])
		value = -rng.stream(SeededRng.SPAWN).randf_range(20.0, 180.0)
	elif roll > 0.74:
		# The basket-against-a-list case: store credit, a tax-exempt certificate, an
		# organised-play kit. This is where the partial verdict lives.
		family = "entitlement"
		tags = PackedStringArray(["entitlement", "reconciliation"])
		value = rng.stream(SeededRng.SPAWN).randf_range(8.0, 60.0)
	elif roll > 0.68:
		family = "payment"
		tags = PackedStringArray(["payment"])
		value = rng.stream(SeededRng.SPAWN).randf_range(10.0, 90.0)

	var candidates: Array = registry.by_field(&"document_type", "family", family)
	if candidates.is_empty():
		candidates = registry.by_type(&"document_type")
	if candidates.is_empty():
		return
	var document_id: StringName = (rng.pick(SeededRng.SPAWN, candidates) as ContentDefinition).id

	# The director is consulted only now, once someone is actually arriving at the
	# counter. Asking earlier spent the shift's suspicious budget on people who only
	# wanted a table, and the forgeries never reached anybody's hands.
	var suspicious: bool = director.should_be_suspicious(now)
	var tier: int = director.tier_for_next(toolkit_tier())

	# Most regulars are exactly who they appear to be. If a familiar face were as likely
	# to be running something as a stranger, trust would be a trap and the ledger would
	# be pointless -- so a scheduled suspicious encounter goes to a stranger unless this
	# is one of the rare long cons, where the twenty honest transactions are the point.
	if suspicious and person.trust_score() > 0.25 and not _is_long_con(person):
		person = people.create_stranger()
	var encounter: Encounter = verification.create(
		document_id, person, tags, suspicious, tier, value, owned_tools
	)
	if encounter != null:
		encounter.opened_tick = now
		waiting_encounters.append(encounter)
		if suspicious and not encounter.is_forged():
			# The document that turned up had nothing catchable on it. Put the slot back:
			# the shift is owed this encounter and somebody else will carry it.
			director.return_slot(now)


## Buying a single from the public: the money becomes an asset in the case, valued
## against a buylist that moves. Over-grade and you overpay; the ledger finds out later.
func _take_trade_in(encounter: Encounter, offer: float) -> void:
	if economy.money < offer:
		bus.publish(
			EventCatalog.CUSTOMER_LEFT,
			{"person": String(encounter.person.id), "reason": "no cash for the buy-in"}
		)
		return
	var sets: Array = registry.by_type(&"card_set")
	if sets.is_empty():
		economy.spend(offer, "trade-in")
		return
	var card_set: ContentDefinition = rng.pick(SeededRng.MARKET, sets)
	var single := CardCase.Single.new()
	single.set_id = card_set.id
	single.rarity = "rare"
	# The offer was made against an assessment; the market pays what the market pays.
	single.market_value = offer * rng.stream(SeededRng.MARKET).randf_range(0.75, 1.6)
	single.assessed_grade = rng.stream(SeededRng.MARKET).randf_range(7.0, 9.5)
	single.true_grade = clampf(
		single.assessed_grade + rng.stream(SeededRng.MARKET).randfn(0.0, 0.8), 1.0, 10.0
	)
	single.authentic = not encounter.is_forged()
	if not single.authentic:
		single.market_value = 0.0  # a fake is worth nothing, and you paid for it
	card_case.buy_single(single, offer, economy)


## A long con is someone whose history is the mechanism: honest twenty times, and then
## once not. They are rare on purpose -- if they were common, the answer would always be
## "trust nobody" and the person layer would collapse into a checklist.
func _is_long_con(person: Person) -> bool:
	var npc: ContentDefinition = registry.get_definition(person.id)
	return npc != null and npc.get_text("trust_arc") == "long_con"


func kitchen_closed() -> bool:
	return not kitchen.open or not economy.holds(&"base:food_service")
