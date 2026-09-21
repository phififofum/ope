extends GdUnitTestSuite

## Determinism is not a nicety here: it is what makes headless tests, replayable bug
## reports and debuggable desyncs possible.


func test_same_seed_produces_the_same_sequence() -> void:
	var first := SeededRng.new(1234)
	var second := SeededRng.new(1234)
	for _index: int in range(20):
		assert_int(first.stream(SeededRng.SPAWN).randi()).is_equal(
			second.stream(SeededRng.SPAWN).randi()
		)


func test_different_seeds_diverge() -> void:
	var first := SeededRng.new(1)
	var second := SeededRng.new(2)
	assert_int(first.stream(SeededRng.SPAWN).randi()).is_not_equal(
		second.stream(SeededRng.SPAWN).randi()
	)


func test_streams_are_independent() -> void:
	# Drawing from one stream must not shift another, or adding a customer spawn would
	# change every forgery in the run.
	var undisturbed := SeededRng.new(99)
	var disturbed := SeededRng.new(99)
	for _index: int in range(50):
		disturbed.stream(SeededRng.SPAWN).randi()
	assert_int(disturbed.stream(SeededRng.FORGERY).randi()).is_equal(
		undisturbed.stream(SeededRng.FORGERY).randi()
	)


func test_snapshot_resumes_mid_sequence() -> void:
	var original := SeededRng.new(7)
	for _index: int in range(10):
		original.stream(SeededRng.MARKET).randi()
	var expected: int = original.stream(SeededRng.MARKET).randi()

	var replayed := SeededRng.new(7)
	for _index: int in range(10):
		replayed.stream(SeededRng.MARKET).randi()
	var snapshot: Dictionary = replayed.snapshot()

	var restored := SeededRng.new(0)
	restored.restore(snapshot)
	assert_int(restored.stream(SeededRng.MARKET).randi()).is_equal(expected)
	assert_int(restored.session_seed()).is_equal(7)


func test_weighted_pick_respects_zero_weights() -> void:
	var rng := SeededRng.new(3)
	for _index: int in range(100):
		var picked: Variant = rng.pick_weighted(SeededRng.FORGERY, ["never", "always"], [0.0, 1.0])
		assert_str(str(picked)).is_equal("always")


func test_pick_on_empty_options_is_null_not_a_crash() -> void:
	var rng := SeededRng.new(3)
	assert_object(rng.pick(SeededRng.SPAWN, [])).is_null()
