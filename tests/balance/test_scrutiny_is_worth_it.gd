extends GdUnitTestSuite

## One claim: a careless player misses forgeries a careful one catches.
##
## Scrutiny has to pay for itself or the whole thesis collapses. Measured as missed
## forgeries rather than as reputation, and aggregated across seeds, because any single
## day can go well for a careless player.

const SEEDS: Array = [21, 22, 23]

var registry: ContentRegistry


func before() -> void:
	registry = PolicyProbe.content()


func test_a_careless_player_misses_forgeries_a_careful_one_catches() -> void:
	var careless: Dictionary = PolicyProbe.tally(registry, BotPlayer.Policy.CARELESS, SEEDS)
	var careful: Dictionary = PolicyProbe.tally(registry, BotPlayer.Policy.PARANOID, SEEDS)

	(
		assert_int(int(careful["forged"]))
		. override_failure_message(
			"no forgeries reached the counter at all; the director is not sending any"
		)
		. is_greater(0)
	)
	(
		assert_int(int(careful["missed"]))
		. override_failure_message(
			(
				"careful missed %d of %d, careless missed %d of %d"
				% [careful["missed"], careful["forged"], careless["missed"], careless["forged"]]
			)
		)
		. is_less(int(careless["missed"]))
	)
	assert_int(int(careless["strikes"])).is_greater(int(careful["strikes"]))
	# Deliberately not asserted here: that the exhaustive checker ends with better
	# reputation than the careless one. It does not, and the design says it should not --
	# checking everything is a mistake, and a shop that serves forty people a day is worse
	# regarded than one that serves four hundred badly. The claim that reputation is built
	# by judgement rather than by volume belongs to triage, and lives in
	# test_judgement_beats_volume.gd.
