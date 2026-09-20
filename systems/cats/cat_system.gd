class_name CatSystem
extends RefCounted

## The cats, which are a mechanical pillar rather than set dressing.
##
## Three jobs: they suppress pests, they react to people at the counter, and customers
## notice them. The second one is the delicate part — a cat is the most unreliable and
## most beloved signal in the game, and it must stay noisy. It points attention. It never
## resolves anything.

const MAX_RESIDENTS: int = 3
const BOND_PER_INTERACTION: float = 0.06


class Cat:
	extends RefCounted
	var definition_id: StringName
	var given_name: String
	var traits: Dictionary = {}
	var bond: Dictionary = {}  ## player id -> 0..1; the cat has a favourite
	var fed_day: int = -1
	var well_kept: float = 0.8
	var outside: bool = false

	func average_bond() -> float:
		if bond.is_empty():
			return 0.0
		var total: float = 0.0
		for value: float in bond.values():
			total += value
		return total / float(bond.size())

	func trait_weight(trait_name: String) -> float:
		return float(traits.get(trait_name, 0.0))


var registry: ContentRegistry
var bus: EventBus
var rng: SeededRng

var residents: Array[Cat] = []
var stray_present: bool = false
var stray_feedings: int = 0

var _day: int = 1


func _init(p_registry: ContentRegistry, p_bus: EventBus, p_rng: SeededRng) -> void:
	registry = p_registry
	bus = p_bus
	rng = p_rng


## Cats are not bought. A stray turns up at the back door during the dead hours once the
## pests are bad enough, and stays if you keep feeding it.
func offer_stray(pest_pressure: float) -> bool:
	if residents.size() >= MAX_RESIDENTS or stray_present:
		return false
	if pest_pressure < 0.3:
		return false
	stray_present = rng.stream(SeededRng.CAT_MOOD).randf() < 0.25
	return stray_present


func feed_stray() -> Cat:
	if not stray_present:
		return null
	stray_feedings += 1
	if stray_feedings < 3:
		return null
	stray_present = false
	stray_feedings = 0
	return adopt(_random_breed())


func adopt(definition_id: StringName, given_name: String = "") -> Cat:
	if residents.size() >= MAX_RESIDENTS:
		return null
	var definition: ContentDefinition = registry.get_definition(definition_id)
	if definition == null:
		return null
	var cat := Cat.new()
	cat.definition_id = definition_id
	cat.given_name = given_name if not given_name.is_empty() else _name_for(definition)
	for trait_name: String in (definition.get_value("trait_weights", {}) as Dictionary).keys():
		cat.traits[trait_name] = float(
			(definition.get_value("trait_weights") as Dictionary)[trait_name]
		)
	residents.append(cat)
	return cat


## Total hunting effectiveness. Beyond two cats, territorial behaviour costs more than
## the extra coverage returns — a soft cap that makes the third cat a real decision.
func hunting_pressure() -> float:
	var total: float = 0.0
	for index: int in range(residents.size()):
		var cat: Cat = residents[index]
		var definition: ContentDefinition = registry.get_definition(cat.definition_id)
		var base: float = definition.get_number("base_hunting", 0.5) if definition != null else 0.5
		var territorial_penalty: float = 1.0 if index < 2 else 0.55
		total += base * territorial_penalty * (0.4 + 0.6 * cat.average_bond()) * cat.well_kept
	return total


## The counter tell. A bonded, calm cat that only reacts to real trouble is the best tool
## in the building; a twitchy one that hisses at everyone is useless. Both exist, because
## false positives are the mechanic.
func counter_reaction(person: Person) -> Dictionary:
	var best: Cat = null
	for cat: Cat in residents:
		if cat.outside:
			continue
		if best == null or cat.average_bond() > best.average_bond():
			best = cat
	if best == null or best.average_bond() < 0.25:
		return {"reacted": false, "cat": "", "confidence": 0.0}

	var definition: ContentDefinition = registry.get_definition(best.definition_id)
	var sensitivity: float = (
		definition.get_number("counter_sensitivity", 0.4) if definition != null else 0.4
	)
	var false_positive: float = (
		definition.get_number("false_positive_rate", 0.15) if definition != null else 0.15
	)

	var roll: float = rng.stream(SeededRng.CAT_MOOD).randf()
	var reacted: bool = roll < person.nervousness * sensitivity or roll < false_positive
	if reacted:
		bus.publish(
			EventCatalog.CAT_REACTED,
			{"cat": best.given_name, "person": String(person.id), "nervousness": person.nervousness}
		)
	return {
		"reacted": reacted,
		"cat": best.given_name,
		"confidence": sensitivity * (1.0 - false_positive)
	}


## Customers notice the cat. A well-kept, visible one lifts footfall and patience; a
## neglected one does the opposite, and a cat on the kitchen pass is an inspection risk.
func customer_appeal() -> float:
	var appeal: float = 0.0
	for cat: Cat in residents:
		var definition: ContentDefinition = registry.get_definition(cat.definition_id)
		var base: float = (
			definition.get_number("customer_appeal", 0.5) if definition != null else 0.5
		)
		appeal += base * cat.well_kept
	return appeal


func feed(cat: Cat, inventory: Inventory) -> bool:
	# Food comes out of stock you could otherwise sell.
	var food: Array = registry.by_tags(&"product", PackedStringArray(["ingredient"]))
	if not food.is_empty():
		inventory.sell((food[0] as ContentDefinition).id, 1)
	cat.fed_day = _day
	cat.well_kept = clampf(cat.well_kept + 0.1, 0.0, 1.0)
	bus.publish(EventCatalog.CAT_FED, {"cat": cat.given_name})
	return true


func play_with(cat: Cat, player_id: String) -> void:
	cat.bond[player_id] = clampf(
		float(cat.bond.get(player_id, 0.0)) + BOND_PER_INTERACTION, 0.0, 1.0
	)
	cat.well_kept = clampf(cat.well_kept + 0.02, 0.0, 1.0)


## Mischief. Cats generate work, which is entirely the point: an escape artist that gets
## out during the evening rush stops the room while five players try to catch it, and
## that is the best five minutes of somebody's session.
func tick_mischief(customers_present: int) -> Array[String]:
	var incidents: Array[String] = []
	for cat: Cat in residents:
		var chance: float = 0.0008 * (1.0 + float(customers_present) * 0.05)
		if (
			rng.stream(SeededRng.CAT_MOOD).randf()
			< chance * (1.0 + cat.trait_weight("escape_artist") * 4.0)
		):
			cat.outside = true
			incidents.append("%s got out the front door" % cat.given_name)
		elif (
			rng.stream(SeededRng.CAT_MOOD).randf()
			< chance * (1.0 + cat.trait_weight("thief") * 3.0)
		):
			incidents.append("%s knocked a display over" % cat.given_name)
	return incidents


func recover_cat(cat: Cat) -> void:
	cat.outside = false
	cat.well_kept = clampf(cat.well_kept - 0.05, 0.0, 1.0)


func advance_day(new_day: int) -> void:
	_day = new_day
	for cat: Cat in residents:
		if cat.fed_day < _day - 1:
			cat.well_kept = clampf(cat.well_kept - 0.12, 0.0, 1.0)


func _random_breed() -> StringName:
	var breeds: Array = registry.by_type(&"cat")
	if breeds.is_empty():
		return &""
	return (rng.pick(SeededRng.CAT_MOOD, breeds) as ContentDefinition).id


func _name_for(_definition: ContentDefinition) -> String:
	var names: PackedStringArray = [
		"Biscuit",
		"Mackerel",
		"Tuesday",
		"Ledger",
		"Sleeve",
		"Meeple",
		"Hazard",
		"Gambit",
		"Espresso",
		"Rulebook",
		"Deuce",
		"Cardboard",
	]
	return str(rng.pick(SeededRng.CAT_MOOD, Array(names)))
