class_name Maintenance
extends RefCounted

## The ambient work: mess, spills, bins, pests, and equipment that wears out.
##
## This is the pillar-2 engine. Every task below runs on its own clock so there is always
## something worth doing — and neglecting any of them costs something specific rather
## than nudging an abstract score.

const CLEAN: float = 1.0
const INSPECTION_FAIL_THRESHOLD: float = 0.35

var bus: EventBus
var rng: SeededRng

var cleanliness: float = 0.85
var waste_units: float = 0.0
var pest_pressure: float = 0.0  ## 0 none .. 1 infestation
var equipment_wear: Dictionary = {}  ## fixture id -> 0..1
var tables_dirty: int = 0


func _init(p_bus: EventBus, p_rng: SeededRng) -> void:
	bus = p_bus
	rng = p_rng


## One simulation tick of mess accumulating. Traffic makes mess; mess plus waste attracts
## rats; rats chew cardboard, which in a room full of board games is a much sharper threat
## than it would be in a grocery shop.
func tick(customers_served: int, food_orders: int, cats_hunting: float) -> void:
	# Per tick, with customers_served and food_orders as running day totals: mess
	# accumulates with how busy the room has been, not with how long it has existed.
	# Tuned against a 30,000-tick day: a busy day with nobody cleaning costs roughly a
	# third of the cleanliness score and fills the bins, rather than reaching zero by
	# lunchtime.
	cleanliness = clampf(
		cleanliness - float(customers_served) * 0.0000003 - float(food_orders) * 0.0000005, 0.0, 1.0
	)
	waste_units += float(food_orders) * 0.00005 + float(customers_served) * 0.000038
	if rng.stream(SeededRng.BREAKAGE).randf() < float(customers_served) * 0.0000045:
		tables_dirty += 1

	var attraction: float = (waste_units * 0.0000002) + (1.0 - cleanliness) * 0.000002
	pest_pressure = clampf(pest_pressure + attraction - cats_hunting * 0.00001, 0.0, 1.0)
	if pest_pressure > 0.6 and rng.stream(SeededRng.BREAKAGE).randf() < 0.02:
		bus.publish(EventCatalog.PEST_SIGHTED, {"pressure": pest_pressure})


func clean(effort_seconds: float) -> void:
	cleanliness = clampf(cleanliness + effort_seconds * 0.004, 0.0, 1.0)


func empty_bins() -> void:
	waste_units = 0.0
	pest_pressure = maxf(0.0, pest_pressure - 0.08)


func reset_table() -> void:
	tables_dirty = maxi(0, tables_dirty - 1)
	cleanliness = clampf(cleanliness + 0.004, 0.0, 1.0)


func wear_equipment(fixture_id: StringName, hours: float) -> void:
	equipment_wear[fixture_id] = clampf(
		float(equipment_wear.get(fixture_id, 0.0)) + hours * 0.02, 0.0, 1.0
	)


func service(fixture_id: StringName, economy: Economy) -> bool:
	var wear: float = float(equipment_wear.get(fixture_id, 0.0))
	if wear <= 0.0:
		return true
	if not economy.spend(60.0 + wear * 180.0, "service %s" % fixture_id):
		return false
	equipment_wear[fixture_id] = 0.0
	return true


## Equipment that will fail soon. An espresso machine failure at 08:00 is a catastrophe,
## and it should always have been foreseeable.
func failing_equipment(threshold: float = 0.8) -> Array:
	var failing: Array = []
	for fixture_id: StringName in equipment_wear.keys():
		if float(equipment_wear[fixture_id]) >= threshold:
			failing.append(fixture_id)
	return failing


## What an inspector would find today.
func inspection_result() -> Dictionary:
	var failures: PackedStringArray = []
	if cleanliness < INSPECTION_FAIL_THRESHOLD:
		failures.append("cleanliness")
	if pest_pressure > 0.5:
		failures.append("pests")
	if waste_units > 60.0:
		failures.append("waste")
	return {"passed": failures.is_empty(), "failures": failures, "cleanliness": cleanliness}


func snapshot() -> Dictionary:
	return {
		"cleanliness": cleanliness,
		"waste": waste_units,
		"pests": pest_pressure,
		"tables_dirty": tables_dirty,
	}
