class_name BotPlayer
extends RefCounted

## A scripted agent that plays the game through the same actions a human uses.
##
## It is not good at the game, and it is not meant to be. It is a liveness and progression
## probe: can a day be completed, does anything soft-lock, does the economy reach a dead
## end, is any objective unreachable. Run nightly across many seeds, it is the closest
## available substitute for playtesting.
##
## Its triage is deliberately simple and a little bad, which is useful: if a simple policy
## cannot keep the shop alive, the tuning is wrong rather than the player.

enum Policy { BALANCED, COUNTER_FIRST, KITCHEN_FIRST, CARELESS, PARANOID, GAMBLER }

var shop: Shop
var policy: Policy
var log: RunLog

var days_played: int = 0
## What the bot decided, so a nightly run can say how a policy behaved rather than only
## what it scored.
var verdict_counts: Dictionary = {}
var tools_used_counts: Dictionary = {}
var actions_taken: int = 0
var soft_lock_ticks: int = 0

## The triage order, built once. It does not change within a run, and rebuilding it every
## tick for every free player was most of what a simulated day cost.
var _order: Array[Callable] = []


func _init(p_shop: Shop, p_policy: Policy = Policy.BALANCED, p_log: RunLog = null) -> void:
	shop = p_shop
	policy = p_policy
	log = p_log


## Plays [param days] days. Returns a report the nightly run reads.
func play(days: int, sample_every_ticks: int = 600) -> Dictionary:
	var day_summaries: Array[Dictionary] = []
	for day_offset: int in range(days):
		shop.start_day(shop.day + (1 if day_offset > 0 else 0))
		_buy_what_we_can_afford()
		var idle_streak: int = 0
		for _tick_index: int in range(Shop.DAY_TICKS):
			shop.tick()
			var now: int = shop.clock.current_tick()
			var free: Array[Shop.PlayerSlot] = shop.free_players(now)
			var acted: bool = false
			for slot: Shop.PlayerSlot in free:
				if _take_one_action(slot, now):
					acted = true
			# A player with nothing to do is a bug. Everyone being busy is not that --
			# the stall worth catching is a free pair of hands that cannot reach the work
			# that is visibly waiting.
			var stalled: bool = not free.is_empty() and not acted and _work_is_waiting()
			idle_streak = idle_streak + 1 if stalled else 0
			if idle_streak > 400:
				soft_lock_ticks += 1
			if log != null and now % sample_every_ticks == 0:
				log.sample(shop.day, now, shop.state_sample())
		day_summaries.append(shop.end_day())
		days_played += 1

	return {
		"days": days_played,
		"actions": actions_taken,
		"soft_lock_ticks": soft_lock_ticks,
		"final_money": shop.economy.money,
		"final_reputation": shop.economy.reputation,
		"insolvent": shop.economy.is_insolvent(),
		"act": shop.act(),
		"staff": shop.staff.employees.size(),
		"unsurfaced_staff_cost": shop.staff.unsurfaced_cost(),
		"sealed": shop.card_case.sealed_ledger(),
		"case_value": shop.card_case.case_value(),
		"stock_value": shop.inventory.stock_value(),
		"verdicts": verdict_counts.duplicate(),
		"tool_use": tools_used_counts.duplicate(),
		"summaries": day_summaries,
	}


## Progression, played badly on purpose: take the cheapest licence you can comfortably
## afford. It is a probe for dead ends -- if the campaign cannot be advanced by a policy
## this simple, the economy is wrong rather than the player.
func _buy_what_we_can_afford() -> void:
	# The careless policy is careless about everything, including the back door. That is
	# the point of it: it is the floor of competence, not a controlled experiment in
	# scrutiny alone.
	if policy == Policy.CARELESS:
		return
	_order_the_thin_shelves()
	var affordable: Array = shop.affordable_licences()
	if not affordable.is_empty():
		shop.buy_licence((affordable[0] as ContentDefinition).id)
	# The gambler wants to buy by the box as soon as anybody will sell it one.
	if policy == Policy.GAMBLER:
		shop.buy_licence(&"base:sealed_distribution")
	_restock_sealed()
	_hire_if_it_helps()


## The morning order. Deliberately crude -- whatever the shop has least of, in modest
## quantity, from the first supplier that carries it -- because the point is to keep the
## floor loop turning, not to play it well.
func _order_the_thin_shelves() -> void:
	if shop.economy.money < 700.0:
		return
	var thin: Array = []
	for product: ContentDefinition in shop.registry.by_type(&"product"):
		if product.get_number("market_price") <= 0.0:
			continue
		if not shop.economy.holds(StringName(product.get_text("licence"))):
			continue
		if shop.inventory.total_units(product.id) <= 4:
			thin.append(product)
	thin.sort_custom(
		func(a: ContentDefinition, b: ContentDefinition) -> bool:
			return shop.inventory.total_units(a.id) < shop.inventory.total_units(b.id)
	)
	for index: int in range(mini(3, thin.size())):
		var product: ContentDefinition = thin[index]
		var suppliers: Array = product.get_value("suppliers", [])
		if suppliers.is_empty():
			continue
		# Cheap things by the case, expensive things two at a time. Ordering a pallet of
		# booster boxes on day three is a way to go broke, and the bot should not.
		var units: int = 12 if product.get_number("base_cost") < 12.0 else 2
		shop.inventory.order(
			StringName(str(suppliers[0])), {product.id: units}, shop.economy, shop.rng
		)


## Orders more of what it opened. Sealed product comes from a distributor like anything
## else, which means it comes with the back-door problem attached -- and a box that
## arrived wrong is only ever found by the person who opens it.
func _restock_sealed() -> void:
	if policy != Policy.GAMBLER or shop.economy.money < 1500.0:
		return
	var sealed: Array = shop.sellable_sealed()
	if sealed.is_empty():
		return
	var cheapest: ContentDefinition = sealed[0]
	for product: ContentDefinition in sealed:
		if product.get_number("base_cost") < cheapest.get_number("base_cost"):
			cheapest = product
	var suppliers: Array = cheapest.get_value("suppliers", [])
	if suppliers.is_empty():
		return
	shop.inventory.order(StringName(str(suppliers[0])), {cheapest.id: 6}, shop.economy, shop.rng)


## Delegation, played badly on purpose. The bot hires the cheapest role it can cover and
## never checks the references -- which is exactly how the audit loop gets exercised.
func _hire_if_it_helps() -> void:
	if shop.economy.money < 1200.0 or shop.staff.employees.size() >= 4:
		return
	var roles: Array = shop.registry.by_type(&"staff_role")
	if roles.is_empty():
		return
	var cheapest: ContentDefinition = roles[0]
	for role: ContentDefinition in roles:
		if role.get_number("wage_per_shift") < cheapest.get_number("wage_per_shift"):
			cheapest = role
	var applicant: StaffSystem.Employee = shop.interview(cheapest.id)
	shop.hire(applicant, shop.players[0], shop.clock.current_tick())


## Work a free pair of hands could actually pick up. An order that is cooking is not
## waiting for anyone -- counting it would report a stall every time the griddle is busy.
func _work_is_waiting() -> bool:
	if not shop.waiting_encounters.is_empty():
		return true
	if not shop.library.awaiting_check.is_empty():
		return true
	if shop.maintenance.tables_dirty > 0:
		return true
	for order: Kitchen.Order in shop.kitchen.pending_orders():
		if order.state in [Kitchen.OrderState.WAITING, Kitchen.OrderState.READY]:
			return true
	return false


func _take_one_action(slot: Shop.PlayerSlot, now: int) -> bool:
	if _order.is_empty():
		_order = _priorities()
	for candidate: Callable in _order:
		if candidate.call(slot, now):
			actions_taken += 1
			return true
	return false


## Triage order. Counter first for most policies, because a queue at the counter is the
## most expensive thing to leave alone — but the kitchen burns, so it is never far behind.
##
## Each entry takes the pair of hands and the tick, so the list is built once per run
## rather than once per tick.
func _priorities() -> Array[Callable]:
	var serve := func(slot: Shop.PlayerSlot, now: int) -> bool: return _serve(slot, now)
	var ready_food := func(slot: Shop.PlayerSlot, now: int) -> bool: return shop.run_food(slot, now)
	var cook := func(slot: Shop.PlayerSlot, now: int) -> bool: return shop.cook_next(slot, now)
	var check := func(slot: Shop.PlayerSlot, now: int) -> bool:
		return not shop.check_next_return(slot, now).is_empty()
	var deliveries := func(slot: Shop.PlayerSlot, now: int) -> bool:
		return not shop.receive_deliveries(slot, now, policy == Policy.PARANOID).is_empty()
	var restock := func(slot: Shop.PlayerSlot, now: int) -> bool:
		return shop.restock_shelves(slot, now) > 0
	var clean := func(slot: Shop.PlayerSlot, now: int) -> bool:
		if shop.maintenance.cleanliness > 0.8 and shop.maintenance.tables_dirty == 0:
			return false
		shop.clean_up(slot, now)
		return true
	var case_work := func(slot: Shop.PlayerSlot, now: int) -> bool:
		# Sell singles when the till is thin. Money in cardboard is money not in coffee --
		# except for the one card worth putting on the wall, which is worth more there.
		if shop.card_case.stock.is_empty():
			return false
		if shop.economy.money > 900.0 and shop.card_case.showcase.size() >= 2:
			return false
		var sell_above: float = 12.0 if shop.economy.money < 900.0 else 0.0
		var result: Dictionary = shop.work_the_case(slot, now, sell_above, 90.0)
		return int(result["sold"]) + int(result["displayed"]) > 0
	var rip := func(slot: Shop.PlayerSlot, now: int) -> bool:
		# The gambler opens the biggest thing it can pay for. It is a probe, not a
		# strategy: a nightly run that shows this policy ahead on net worth means the
		# pull tables are wrong, because the design says a rip costs more than it returns.
		if policy != Policy.GAMBLER or shop.economy.money < 400.0:
			return false
		var sealed: Array = shop.sellable_sealed()
		if sealed.is_empty():
			return false
		var biggest: ContentDefinition = sealed[0]
		for product: ContentDefinition in sealed:
			if product.get_number("market_price") > biggest.get_number("market_price"):
				biggest = product
		return bool(shop.rip_sealed(slot, now, biggest.id).get("opened", false))
	var audit := func(slot: Shop.PlayerSlot, now: int) -> bool:
		# The late game's core activity: forensic verification on your own shop. Same
		# verb, new object -- and it only pays once there are staff to audit.
		if shop.staff.employees.is_empty() or shop.staff.unsurfaced_cost() < 60.0:
			return false
		return not shop.audit_staff(slot, now).is_empty()
	var cats := func(slot: Shop.PlayerSlot, now: int) -> bool:
		if shop.cats.residents.is_empty() and not shop.cats.stray_present:
			return false
		shop.tend_cats(slot, now)
		return true

	match policy:
		Policy.KITCHEN_FIRST:
			return [
				ready_food,
				cook,
				serve,
				check,
				deliveries,
				restock,
				case_work,
				rip,
				audit,
				clean,
				cats
			]
		Policy.COUNTER_FIRST:
			return [
				serve,
				ready_food,
				cook,
				deliveries,
				check,
				restock,
				case_work,
				rip,
				audit,
				clean,
				cats
			]
		Policy.GAMBLER:
			return [
				rip, serve, ready_food, cook, check, deliveries, restock, case_work, clean, cats
			]
		_:
			return [
				serve,
				ready_food,
				cook,
				check,
				deliveries,
				restock,
				case_work,
				rip,
				audit,
				clean,
				cats
			]


## The bot's verdict policy. Deliberately imperfect in different directions, so a nightly
## run across policies says something about the tuning rather than about one strategy.
func _serve(slot: Shop.PlayerSlot, now: int) -> bool:
	if shop.waiting_encounters.is_empty():
		return false
	var encounter: Encounter = shop.waiting_encounters[0]

	var tools: PackedStringArray = []
	match policy:
		Policy.CARELESS:
			tools = PackedStringArray()
		Policy.PARANOID:
			tools = shop.owned_tools.duplicate()
		_:
			# Spend scrutiny where it is worth spending: on strangers and on value.
			if encounter.person.trust_score() < 0.3 or absf(encounter.value) > 60.0:
				tools = shop.owned_tools.duplicate()
			else:
				tools = PackedStringArray(["base:naked_eye"])

	encounter.evaluate_with(
		shop.verification.rules, tools, shop.verification.today(), shop.owned_tools
	)
	var verdict: Encounter.Verdict = Encounter.Verdict.APPROVE
	var reason: String = ""
	# A buy-in you cannot cover is not a judgement call. Declining costs a little
	# reputation; taking it costs the rent.
	if encounter.value < 0.0 and shop.economy.money < absf(encounter.value) + 400.0:
		verdict = Encounter.Verdict.DECLINE
		reason = "cannot_fund"
	elif encounter.has_blocking_failure():
		verdict = Encounter.Verdict.DECLINE
	elif encounter.has_item_scoped_failure():
		verdict = Encounter.Verdict.PARTIAL
	elif encounter.has_unchecked_rule():
		# Scrutiny it owns and did not spend. Declining is always available and only
		# mildly expensive -- but it costs a customer, so only the paranoid policy takes
		# that trade every time.
		if policy == Policy.PARANOID:
			verdict = Encounter.Verdict.DECLINE

	var name: String = Encounter.verdict_name(verdict)
	verdict_counts[name] = int(verdict_counts.get(name, 0)) + 1
	tools_used_counts[str(tools.size())] = int(tools_used_counts.get(str(tools.size()), 0)) + 1
	return not shop.serve_counter(slot, verdict, tools, now, reason).is_empty()
