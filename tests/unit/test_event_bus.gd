extends GdUnitTestSuite

var bus: EventBus


func before_test() -> void:
	bus = EventBus.new()


func test_notification_reaches_every_subscriber() -> void:
	var received: Array = []
	bus.subscribe(EventCatalog.CUSTOMER_SERVED, func(p: Dictionary) -> void: received.append(p))
	bus.subscribe(EventCatalog.CUSTOMER_SERVED, func(p: Dictionary) -> void: received.append(p))
	bus.publish(EventCatalog.CUSTOMER_SERVED, {"customer": "regular"})
	assert_int(received.size()).is_equal(2)


func test_unknown_event_is_refused_rather_than_silently_accepted() -> void:
	var ok: bool = bus.subscribe(&"not_a_real_event", func(_p: Dictionary) -> void: pass)
	assert_bool(ok).is_false()
	assert_int(bus.errors().size()).is_equal(1)


func test_query_aggregates_as_a_product() -> void:
	bus.subscribe(EventCatalog.PRICE_REQUESTED, func(_p: Dictionary) -> float: return 1.5)
	bus.subscribe(EventCatalog.PRICE_REQUESTED, func(_p: Dictionary) -> float: return 2.0)
	assert_float(bus.query(EventCatalog.PRICE_REQUESTED, {}, 10.0)).is_equal_approx(30.0, 0.0001)


func test_query_aggregates_as_a_sum() -> void:
	bus.subscribe(EventCatalog.INSPECTION_TIME_REQUESTED, func(_p: Dictionary) -> float: return 2.0)
	bus.subscribe(EventCatalog.INSPECTION_TIME_REQUESTED, func(_p: Dictionary) -> float: return 3.0)
	assert_float(bus.query(EventCatalog.INSPECTION_TIME_REQUESTED, {}, 5.0)).is_equal_approx(
		10.0, 0.0001
	)


func test_query_result_does_not_depend_on_subscription_order() -> void:
	var forwards := EventBus.new()
	forwards.subscribe(EventCatalog.PRICE_REQUESTED, func(_p: Dictionary) -> float: return 0.5, "a")
	forwards.subscribe(EventCatalog.PRICE_REQUESTED, func(_p: Dictionary) -> float: return 4.0, "b")
	var backwards := EventBus.new()
	backwards.subscribe(
		EventCatalog.PRICE_REQUESTED, func(_p: Dictionary) -> float: return 4.0, "b"
	)
	backwards.subscribe(
		EventCatalog.PRICE_REQUESTED, func(_p: Dictionary) -> float: return 0.5, "a"
	)
	assert_float(forwards.query(EventCatalog.PRICE_REQUESTED, {}, 3.0)).is_equal_approx(
		backwards.query(EventCatalog.PRICE_REQUESTED, {}, 3.0), 0.0001
	)


func test_a_veto_stops_the_attempt_and_says_who_and_why() -> void:
	bus.subscribe(
		EventCatalog.SALE_ATTEMPTED, func(_p: Dictionary) -> String: return "no ID", "compliance"
	)
	var outcome: EventOutcome = bus.attempt(EventCatalog.SALE_ATTEMPTED, {})
	assert_bool(outcome.allowed).is_false()
	assert_str(outcome.reason).is_equal("no ID")
	assert_str(outcome.vetoed_by).is_equal("compliance")


func test_an_empty_reason_is_not_a_veto() -> void:
	bus.subscribe(EventCatalog.SALE_ATTEMPTED, func(_p: Dictionary) -> String: return "")
	assert_bool(bus.attempt(EventCatalog.SALE_ATTEMPTED, {}).allowed).is_true()


func test_priority_decides_which_veto_is_reported() -> void:
	bus.subscribe(
		EventCatalog.SALE_ATTEMPTED, func(_p: Dictionary) -> String: return "late", "z", 10
	)
	bus.subscribe(
		EventCatalog.SALE_ATTEMPTED, func(_p: Dictionary) -> String: return "early", "a", -10
	)
	assert_str(bus.attempt(EventCatalog.SALE_ATTEMPTED, {}).reason).is_equal("early")


func test_unsubscribing_an_owner_removes_all_of_its_handlers() -> void:
	bus.subscribe(EventCatalog.CUSTOMER_SERVED, func(_p: Dictionary) -> void: pass, "mod_a")
	bus.subscribe(EventCatalog.SALE_ATTEMPTED, func(_p: Dictionary) -> String: return "x", "mod_a")
	bus.subscribe(EventCatalog.CUSTOMER_SERVED, func(_p: Dictionary) -> void: pass, "mod_b")
	assert_int(bus.unsubscribe_owner("mod_a")).is_equal(2)
	assert_int(bus.subscriber_count(EventCatalog.CUSTOMER_SERVED)).is_equal(1)
	assert_bool(bus.attempt(EventCatalog.SALE_ATTEMPTED, {}).allowed).is_true()


func test_a_freed_subscriber_is_dropped_instead_of_taking_the_game_down() -> void:
	var listener := Node.new()
	bus.subscribe(EventCatalog.CUSTOMER_SERVED, Callable(listener, "queue_free"), "mod_a")
	listener.free()
	bus.publish(EventCatalog.CUSTOMER_SERVED, {})
	assert_int(bus.subscriber_count(EventCatalog.CUSTOMER_SERVED)).is_equal(0)
	assert_int(bus.errors().size()).is_equal(1)
