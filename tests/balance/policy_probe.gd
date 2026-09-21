class_name PolicyProbe
extends RefCounted

## Plays a bot policy across seeds and reports what it cost and what it caught.
##
## Shared by the balance suites, which are one claim per file on purpose: three of these
## comparisons were eleven minutes of a twenty-minute pipeline, and split across files CI
## runs them at the same time instead of one after another.
##
## Each comparison plays whole days at 20 Hz through the same actions a human uses, so it
## is slow by nature rather than by accident. What it buys is a claim about the design
## that is measured rather than asserted.


## Every definition the game ships, loaded once per suite.
static func content() -> ContentRegistry:
	var registry := ContentRegistry.new()
	var loader := ContentLoader.new(registry)
	loader.load_all("res://content", "res://tests/no_mods")
	return registry


static func shop(
	registry: ContentRegistry, seed_value: int, players: int = 3, preset: String = "standard"
) -> Shop:
	var built := Shop.new(
		registry,
		EventBus.new(),
		SeededRng.new(seed_value),
		Director.Profile.preset(preset),
		players
	)
	built.open_for_business(600.0)
	return built


## The tally is a Dictionary because GDScript lambdas capture locals by value: an int
## accumulated in a closure silently stays zero.
static func tally(
	registry: ContentRegistry, policy: BotPlayer.Policy, seeds: Array, days: int = 5
) -> Dictionary:
	var totals: Dictionary = {
		"forged": 0,
		"missed": 0,
		"strikes": 0,
		"reputation": 0.0,
		"net_worth": 0.0,
		"licences": 0,
		"served": 0,
		"walked_out": 0,
	}
	for seed_value: int in seeds:
		var bus := EventBus.new()
		var played := Shop.new(
			registry, bus, SeededRng.new(seed_value), Director.Profile.preset("standard"), 3
		)
		played.open_for_business(600.0)
		bus.subscribe(
			EventCatalog.VERIFICATION_RESOLVED,
			func(payload: Dictionary) -> void:
				if not bool(payload.get("was_forged", false)):
					return
				totals["forged"] = int(totals["forged"]) + 1
				if int(payload.get("outcome", 0)) == Encounter.Outcome.WRONG_APPROVED:
					totals["missed"] = int(totals["missed"]) + 1,
			"test"
		)
		bus.subscribe(
			EventCatalog.STRIKE_ISSUED,
			func(_payload: Dictionary) -> void: totals["strikes"] = int(totals["strikes"]) + 1,
			"test"
		)
		var report: Dictionary = BotPlayer.new(played, policy).play(days)
		totals["reputation"] = float(totals["reputation"]) + float(report["final_reputation"])
		# A licence is an asset the till paid for, and the shop that bought three more of
		# them is further through the campaign, not poorer.
		totals["licences"] = int(totals["licences"]) + played.economy.licences.size()
		# Cash, the case and the stock, kept for the failure messages rather than asserted
		# on: see the note in test_judgement_beats_volume.gd for why a single net-worth
		# number cannot carry a claim about judgement.
		totals["net_worth"] = (
			float(totals["net_worth"])
			+ float(report["final_money"])
			+ played.card_case.case_value()
			+ played.inventory.stock_value()
		)
		totals["served"] = int(totals["served"]) + played.served_today
		totals["walked_out"] = int(totals["walked_out"]) + played.walked_out
	return totals


## Missed forgeries as a fraction of the forgeries that reached the counter. The rate
## rather than the count: a careless player serves more people and therefore sees more
## forgeries, so comparing totals would flatter them for being fast.
static func miss_rate(counted: Dictionary) -> float:
	var seen: int = int(counted["forged"])
	return 0.0 if seen == 0 else float(counted["missed"]) / float(seen)
