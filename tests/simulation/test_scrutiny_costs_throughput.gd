extends GdUnitTestSuite

## One claim: checking everything costs customers.
##
## The load-bearing one. A shift contains far more checkable material than checkable
## time, so scrutiny has to be spent rather than applied -- otherwise "scrutiny is a
## budget" is a slogan and not a mechanic.

const SEEDS: Array = [21, 22, 23]
const DAYS: int = 4

var registry: ContentRegistry


func before() -> void:
	registry = PolicyProbe.content()


func test_scrutiny_costs_throughput() -> void:
	var careless: Dictionary = PolicyProbe.tally(registry, BotPlayer.Policy.CARELESS, SEEDS, DAYS)
	var triage: Dictionary = PolicyProbe.tally(registry, BotPlayer.Policy.BALANCED, SEEDS, DAYS)
	var exhaustive: Dictionary = PolicyProbe.tally(registry, BotPlayer.Policy.PARANOID, SEEDS, DAYS)

	(
		assert_int(int(exhaustive["walked_out"]))
		. override_failure_message(
			(
				"walked out -- careless %d, triage %d, exhaustive %d: checking everything is free"
				% [careless["walked_out"], triage["walked_out"], exhaustive["walked_out"]]
			)
		)
		. is_greater(int(careless["walked_out"]))
	)
	assert_int(int(triage["walked_out"])).is_greater(int(careless["walked_out"]))
	# And it has to buy something.
	(
		assert_float(PolicyProbe.miss_rate(exhaustive))
		. override_failure_message(
			(
				"miss rate -- careless %.2f (%d/%d), exhaustive %.2f (%d/%d)"
				% [
					PolicyProbe.miss_rate(careless),
					careless["missed"],
					careless["forged"],
					PolicyProbe.miss_rate(exhaustive),
					exhaustive["missed"],
					exhaustive["forged"],
				]
			)
		)
		. is_less(PolicyProbe.miss_rate(careless))
	)
