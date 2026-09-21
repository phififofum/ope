extends GdUnitTestSuite

## Loop D's opening decision: every sealed unit in the building can be sold or opened.
##
## The claims under test are design claims rather than implementation details. Opening
## costs the sale you gave up; over a long run it returns less than selling would have;
## a card on the wall earns footfall instead of cash; and a box somebody else already
## opened is discovered by the person who opens it next.

var registry: ContentRegistry


func before() -> void:
	registry = ContentRegistry.new()
	var loader := ContentLoader.new(registry)
	loader.load_all("res://content", "res://tests/no_mods")


func _shop(seed_value: int) -> Shop:
	var shop := Shop.new(
		registry, EventBus.new(), SeededRng.new(seed_value), Director.Profile.preset("standard"), 3
	)
	shop.open_for_business(4000.0)
	return shop


func _a_sealed_box() -> ContentDefinition:
	for product: ContentDefinition in registry.by_type(&"product"):
		var sealed: Dictionary = product.get_value("sealed", {})
		if not sealed.is_empty() and int(sealed.get("packs", 1)) >= 24:
			return product
	return null


func test_every_sealed_product_names_a_set_that_exists() -> void:
	var sealed_count: int = 0
	for product: ContentDefinition in registry.by_type(&"product"):
		if product.get_text("category") != "sealed_product":
			continue
		sealed_count += 1
		var sealed: Dictionary = product.get_value("sealed", {})
		(
			assert_bool(sealed.is_empty())
			. override_failure_message("%s is sealed product with nothing inside it" % product.id)
			. is_false()
		)
		assert_object(registry.get_definition(StringName(str(sealed["card_set"])))).is_not_null()
	# If this is ever zero the loop has quietly disappeared from the content.
	assert_int(sealed_count).is_greater(8)


func test_opening_a_box_takes_it_out_of_stock_and_puts_cards_in_the_case() -> void:
	var shop: Shop = _shop(5)
	var box: ContentDefinition = _a_sealed_box()
	assert_object(box).is_not_null()
	_only_stock(shop, box.id, 2)
	var before_units: int = shop.inventory.total_units(box.id)

	var result: Dictionary = shop.rip_sealed(shop.players[0], 0, box.id)

	assert_bool(bool(result["opened"])).is_true()
	assert_int(shop.inventory.total_units(box.id)).is_equal(before_units - 1)
	assert_int(int(result["cards"])).is_equal(
		(
			int(box.get_value("sealed", {})["packs"])
			* int(
				(
					(registry.get_definition(
						StringName(str(box.get_value("sealed", {})["card_set"]))
					))
					. get_number("cards_per_pack")
				)
			)
		)
	)
	assert_int(shop.card_case.stock.size()).is_equal(int(result["cards"]))


func test_opening_costs_the_sale_you_gave_up() -> void:
	# The honest accounting: a rip is measured against the shelf price, not against the
	# wholesale cost, because selling it was always available.
	var shop: Shop = _shop(6)
	var box: ContentDefinition = _a_sealed_box()
	_only_stock(shop, box.id, 1)
	shop.rip_sealed(shop.players[0], 0, box.id)
	var ledger: Dictionary = shop.card_case.sealed_ledger()
	assert_float(float(ledger["retail_forgone"])).is_equal_approx(
		box.get_number("market_price"), 0.01
	)
	assert_int(int(ledger["units_ripped"])).is_equal(1)


func test_ripping_returns_less_than_selling_over_a_long_run() -> void:
	# The design's one promise about the gamble, asserted against the content rather than
	# assumed: across many boxes, what comes out is worth less than what the box sells
	# for. A single box can still beat the shelf, and should.
	var shop: Shop = _shop(11)
	var box: ContentDefinition = _a_sealed_box()
	_only_stock(shop, box.id, 220)
	var beat_the_shelf: int = 0
	for _index: int in range(200):
		var result: Dictionary = shop.card_case.rip(box.id, shop.inventory, shop.economy)
		if not bool(result["opened"]):
			break
		if float(result["value"]) > float(result["forgone"]):
			beat_the_shelf += 1

	var ledger: Dictionary = shop.card_case.sealed_ledger()
	assert_int(int(ledger["units_ripped"])).is_equal(200)
	assert_float(float(ledger["pulled_value"]) / float(ledger["retail_forgone"])).is_less(1.0)
	# ...and it is a gamble rather than a tax: some boxes do pay for themselves.
	assert_int(beat_the_shelf).is_greater(0)


func test_the_same_seed_opens_the_same_cards() -> void:
	var box: ContentDefinition = _a_sealed_box()
	var values: Array[float] = []
	for attempt: int in range(2):
		var shop: Shop = _shop(42)
		_only_stock(shop, box.id, 1)
		values.append(float(shop.card_case.rip(box.id, shop.inventory, shop.economy)["value"]))
	assert_float(values[0]).is_equal_approx(values[1], 0.0001)


func test_a_resealed_box_has_no_hits_left_in_it() -> void:
	# The nastiest vector in the design: you only find out by opening it, and the person
	# who opens it is whoever the box ends up with.
	var shop: Shop = _shop(21)
	var box: ContentDefinition = _a_sealed_box()
	_only_stock(shop, box.id, 1, true)

	var result: Dictionary = shop.card_case.rip(box.id, shop.inventory, shop.economy)

	assert_bool(bool(result["resealed"])).is_true()
	for single: CardCase.Single in shop.card_case.stock:
		(
			assert_bool(single.rarity in ["common", "uncommon"])
			. override_failure_message("a resealed box still produced a %s" % single.rarity)
			. is_true()
		)


## Replaces everything the shop holds of one product, so a test can say exactly what is
## in the building. The opening shop comes stocked, which is right for the game and
## unhelpful for an assertion about one box.
func _only_stock(shop: Shop, product_id: StringName, units: int, suspect: bool = false) -> void:
	var kept: Array[Inventory.Lot] = []
	for lot: Inventory.Lot in shop.inventory.back_room:
		if lot.product_id != product_id:
			kept.append(lot)
	shop.inventory.back_room = kept
	shop.inventory.shelf[product_id] = 0
	shop.inventory.shelf_suspect[product_id] = 0
	shop.inventory.back_room.append(Inventory.Lot.new(product_id, units, 1_000_000, suspect))
	shop.inventory.restock(product_id, units)


func test_a_card_on_the_wall_draws_people_instead_of_cash() -> void:
	var shop: Shop = _shop(31)
	var single := CardCase.Single.new()
	single.set_id = (registry.by_type(&"card_set")[0] as ContentDefinition).id
	single.market_value = 400.0
	shop.card_case.stock.append(single)

	assert_float(shop.card_case.display_draw()).is_equal_approx(0.0, 0.0001)
	assert_bool(shop.card_case.put_on_display(single)).is_true()
	assert_float(shop.card_case.display_draw()).is_greater(0.1)
	# It is not for sale while it is on the wall -- that is the cost of showing it.
	assert_float(shop.card_case.sell_single(single, shop.economy)).is_equal(0.0)
	assert_bool(shop.card_case.take_off_display(single)).is_true()
	assert_float(shop.card_case.sell_single(single, shop.economy)).is_greater(0.0)


func test_the_wall_only_holds_what_the_glass_holds() -> void:
	var shop: Shop = _shop(32)
	for index: int in range(24):
		var single := CardCase.Single.new()
		single.set_id = (registry.by_type(&"card_set")[0] as ContentDefinition).id
		single.market_value = 50.0 + float(index)
		shop.card_case.stock.append(single)

	shop.work_the_case(shop.players[0], 0, 0.0, 10.0)

	var capacity: int = shop.card_case.showcase_capacity
	assert_int(capacity).is_between(2, 24)
	assert_int(shop.card_case.showcase.size()).is_equal(capacity)
	# The glass holds the best of them, not the first few through the door.
	var lowest_shown: float = 1_000_000.0
	for single: CardCase.Single in shop.card_case.showcase:
		lowest_shown = minf(lowest_shown, single.market_value)
	assert_float(lowest_shown).is_greater_equal(50.0 + float(24 - capacity))


func test_a_bigger_case_shows_more_of_what_you_pulled() -> void:
	var shop: Shop = _shop(33)
	var before_capacity: int = shop.card_case.showcase_capacity
	shop.work_the_case(shop.players[0], 0)
	before_capacity = shop.card_case.showcase_capacity
	assert_bool(shop.buy_fixture(&"base:singles_wall")).is_true()
	shop.work_the_case(shop.players[0], 0)
	assert_int(shop.card_case.showcase_capacity).is_greater(before_capacity)


func test_selling_sealed_over_the_counter_is_recorded_beside_ripping() -> void:
	# Both halves of the decision land in the same ledger, which is the only way the
	# comparison the design promises is worth anything.
	var shop: Shop = _shop(8)
	var box: ContentDefinition = _a_sealed_box()
	_only_stock(shop, box.id, 3)
	shop.economy.grant_licence(StringName(box.get_text("licence")))
	var sale: Dictionary = shop.inventory.sell_one(box.id)
	assert_int(int(sale["sold"])).is_equal(1)
	shop.card_case.record_sealed_sale(box.get_number("market_price"))
	shop.rip_sealed(shop.players[0], 0, box.id)

	var ledger: Dictionary = shop.card_case.sealed_ledger()
	assert_int(int(ledger["units_sold_sealed"])).is_equal(1)
	assert_int(int(ledger["units_ripped"])).is_equal(1)
	assert_float(float(ledger["sealed_revenue"])).is_greater(0.0)


func test_a_shop_that_opens_its_stock_gets_back_less_than_it_gave_up() -> void:
	# The design promise, measured where it can actually be isolated: the gambler's own
	# ledger. Comparing two bots' net worth cannot carry this claim -- two policies differ
	# in what they serve, clean, audit and buy, and ripping is one line of that. The
	# ledger compares like with like: every unit opened, against what it would have sold
	# for.
	var gambler := BotPlayer.new(_shop(77), BotPlayer.Policy.GAMBLER)
	var report: Dictionary = gambler.play(5)
	var ledger: Dictionary = report["sealed"]

	(
		assert_int(int(ledger["units_ripped"]))
		. override_failure_message("the gambler never opened anything, so this asserts nothing")
		. is_greater(0)
	)
	(
		assert_float(float(ledger["return_ratio"]))
		. override_failure_message(
			(
				"opened %d unit(s) worth %.0f and got back %.0f"
				% [
					ledger["units_ripped"],
					ledger["retail_forgone"],
					float(ledger["realised"]) + float(ledger["unsold_value"]),
				]
			)
		)
		. is_less(1.0)
	)
	# It stayed a gamble rather than becoming a tax: the shop is still standing.
	assert_bool(bool(report["insolvent"])).is_false()
	assert_int(int(report["soft_lock_ticks"])).is_equal(0)
