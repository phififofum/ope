extends GdUnitTestSuite

## One claim: triage ends ahead of carelessness on reputation and on progression.
##
## Not asserted, and worth knowing: on cash alone the careless shop is currently ahead
## after five days. It serves more people and it buys nothing, while the triaging shop
## converts its till into licences -- so a "net worth" that counts cash and stock but not
## what the cash bought is measuring the wrong thing, and one that counts the opening
## stock is measuring a constant. Whether carelessness should also lose on the money is
## an open balance question; it is issue 2 in HANDOFF.md.

const SEEDS: Array = [21, 22, 23]

var registry: ContentRegistry


func before() -> void:
	registry = PolicyProbe.content()


func test_triage_beats_carelessness_where_it_counts() -> void:
	var careless: Dictionary = PolicyProbe.tally(registry, BotPlayer.Policy.CARELESS, SEEDS)
	var triage: Dictionary = PolicyProbe.tally(registry, BotPlayer.Policy.BALANCED, SEEDS)

	(
		assert_float(float(triage["reputation"]))
		. override_failure_message(
			(
				"reputation -- careless %.2f, triage %.2f"
				% [careless["reputation"], triage["reputation"]]
			)
		)
		. is_greater(float(careless["reputation"]))
	)
	(
		assert_int(int(triage["licences"]))
		. override_failure_message(
			"licences -- careless %d, triage %d" % [careless["licences"], triage["licences"]]
		)
		. is_greater(int(careless["licences"]))
	)
