class_name PersonFactory
extends RefCounted

## Makes the people who walk in.
##
## A deliberate bias: most of them are exactly who they appear to be. Regulars come back,
## and the game remembers them, because "wait, that's the guy from Tuesday" is the best
## moment this system can produce — and it only happens with a persistent cast rather
## than pure random generation.

const GIVEN_NAMES: PackedStringArray = [
	"Ada",
	"Bo",
	"Cleo",
	"Dev",
	"Esme",
	"Fen",
	"Gus",
	"Hana",
	"Ines",
	"Jo",
	"Kit",
	"Lev",
	"Mira",
	"Nils",
	"Ora",
	"Pax",
	"Quinn",
	"Rae",
	"Sol",
	"Tam",
]
const SURNAMES: PackedStringArray = [
	"Abara",
	"Bhatt",
	"Calder",
	"Duarte",
	"Eze",
	"Fontaine",
	"Grover",
	"Haddad",
	"Ibori",
	"Jelinek",
	"Kowal",
	"Lindqvist",
	"Moreau",
	"Nakamura",
	"Osei",
	"Petrov",
]

var _rng: SeededRng
var _today: int
var _regulars: Array[Person] = []
var _next_index: int = 1


func _init(rng: SeededRng, today: int) -> void:
	_rng = rng
	_today = today


func set_today(day: int) -> void:
	_today = day


func regulars() -> Array[Person]:
	return _regulars


## Returns someone to serve. Regulars recur at a rate that rises with how many you have,
## so the cast thickens over a campaign instead of resetting every shift.
func next_customer(regular_bias: float = 0.35) -> Person:
	if not _regulars.is_empty() and _rng.stream(SeededRng.SPAWN).randf() < regular_bias:
		var regular: Person = _rng.pick(SeededRng.SPAWN, _regulars)
		if regular != null:
			return regular
	return create_stranger()


func create_stranger(min_age: int = 16, max_age: int = 72) -> Person:
	var person := Person.new()
	person.id = StringName("person_%d" % _next_index)
	_next_index += 1
	var given: String = _rng.pick(SeededRng.SPAWN, Array(GIVEN_NAMES))
	var surname: String = _rng.pick(SeededRng.SPAWN, Array(SURNAMES))
	person.display_name = "%s %s" % [given, surname]
	var age: int = _rng.stream(SeededRng.SPAWN).randi_range(min_age, max_age)
	person.dob_days = _today - int(age * 365.25) - _rng.stream(SeededRng.SPAWN).randi_range(0, 364)
	person.portrait_id = "portrait_%s" % String(person.id)
	person.height_cm = _rng.stream(SeededRng.SPAWN).randi_range(152, 196)
	person.patience = _rng.stream(SeededRng.SPAWN).randf_range(0.7, 1.3)
	return person


## Promotes someone into the recurring cast after a clean transaction. Trust is a ratchet
## that builds slowly and breaks fast — and it is never shown as a number.
func record_transaction(person: Person, clean: bool) -> void:
	person.history_count += 1
	if clean:
		person.clean_transactions += 1
	else:
		person.flags.append("flagged_day_%d" % _today)
	if not _regulars.has(person) and person.history_count >= 2 and _regulars.size() < 40:
		_regulars.append(person)
