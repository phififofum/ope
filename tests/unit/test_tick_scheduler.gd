extends GdUnitTestSuite


func test_twenty_ticks_per_second() -> void:
	var scheduler := TickScheduler.new()
	assert_int(scheduler.advance(1.0)).is_equal(8)  # clamped by catch-up protection
	scheduler = TickScheduler.new()
	var ran: int = 0
	for _frame: int in range(60):  # one second at 60fps
		ran += scheduler.advance(1.0 / 60.0)
	assert_int(ran).is_equal(20)
	assert_float(scheduler.elapsed_seconds()).is_equal_approx(1.0, 0.001)


func test_framerate_does_not_change_the_simulation() -> void:
	# Frame times are floats and never sum to exactly a second, so two framerates can
	# land a single tick apart at the boundary. What must not happen is drift: the gap
	# stays at most one tick no matter how long the session runs.
	var slow := TickScheduler.new()
	var fast := TickScheduler.new()
	for _frame: int in range(30 * 60):  # a minute at 30fps
		slow.advance(1.0 / 30.0)
	for _frame: int in range(144 * 60):  # a minute at 144fps
		fast.advance(1.0 / 144.0)
	assert_int(absi(slow.current_tick() - fast.current_tick())).is_less_equal(1)
	assert_int(slow.current_tick()).is_between(1199, 1201)


func test_a_long_stall_drops_the_backlog_instead_of_spiralling() -> void:
	var scheduler := TickScheduler.new()
	var ran: int = scheduler.advance(10.0)
	assert_int(ran).is_equal(TickScheduler.MAX_CATCHUP_TICKS)
	assert_int(scheduler.dropped_ticks()).is_greater(0)


func test_pause_and_time_scale() -> void:
	var scheduler := TickScheduler.new()
	scheduler.set_paused(true)
	assert_int(scheduler.advance(1.0)).is_equal(0)
	scheduler.set_paused(false)
	scheduler.set_time_scale(0.0)
	assert_int(scheduler.advance(1.0)).is_equal(0)


func test_advance_ticks_is_exact() -> void:
	var scheduler := TickScheduler.new()
	scheduler.advance_ticks(500)
	assert_int(scheduler.current_tick()).is_equal(500)
	assert_float(scheduler.elapsed_seconds()).is_equal_approx(25.0, 0.0001)
