class_name EventCatalog
extends RefCounted

## The public event vocabulary: every event name, its kind, and how query results are
## combined. Mod scripts subscribe to these by name, so this catalog is part of the
## public mod API and changing an entry is a breaking change.
##
## Three kinds, from the architecture spec:
##
## [b]Notification[/b] — something happened. Observers cannot alter the outcome.
## [b]Query[/b] — someone is asking. Observers contribute values that are aggregated
## deterministically.
## [b]Cancellable[/b] — something is about to happen. Any observer may veto it, with a
## reason the player can be shown.

enum Kind { NOTIFICATION, QUERY, CANCELLABLE }

## How contributions to a query event are combined. Deterministic: the result cannot
## depend on subscription order.
enum Aggregate { SUM, PRODUCT, MIN, MAX }

# --- Notifications ---------------------------------------------------------------
const SHIFT_STARTED: StringName = &"shift_started"
const SHIFT_ENDED: StringName = &"shift_ended"
const DAY_ENDED: StringName = &"day_ended"
const CUSTOMER_SPAWNED: StringName = &"customer_spawned"
const CUSTOMER_SERVED: StringName = &"customer_served"
const CUSTOMER_LEFT: StringName = &"customer_left"
const VERIFICATION_RESOLVED: StringName = &"verification_resolved"
const ORDER_TAKEN: StringName = &"order_taken"
const ORDER_COMPLETED: StringName = &"order_completed"
const ORDER_FAILED: StringName = &"order_failed"
const GAME_RETURNED: StringName = &"game_returned"
const COMPONENT_CHECK_RESOLVED: StringName = &"component_check_resolved"
const PACK_OPENED: StringName = &"pack_opened"
const CARD_GRADED: StringName = &"card_graded"
const STRIKE_ISSUED: StringName = &"strike_issued"
const LICENCE_GRANTED: StringName = &"licence_granted"
const CAT_FED: StringName = &"cat_fed"
const CAT_REACTED: StringName = &"cat_reacted"
const PEST_SIGHTED: StringName = &"pest_sighted"
const STAFF_ERROR_MADE: StringName = &"staff_error_made"
const MONEY_CHANGED: StringName = &"money_changed"
const REPUTATION_CHANGED: StringName = &"reputation_changed"

# --- Queries ---------------------------------------------------------------------
const PRICE_REQUESTED: StringName = &"price_requested"
const PATIENCE_MODIFIER_REQUESTED: StringName = &"patience_modifier_requested"
const SPAWN_RATE_REQUESTED: StringName = &"spawn_rate_requested"
const FORGERY_RATE_REQUESTED: StringName = &"forgery_rate_requested"
const INSPECTION_TIME_REQUESTED: StringName = &"inspection_time_requested"
const WAGE_REQUESTED: StringName = &"wage_requested"

# --- Cancellables ----------------------------------------------------------------
const SALE_ATTEMPTED: StringName = &"sale_attempted"
const TRADE_IN_ATTEMPTED: StringName = &"trade_in_attempted"
const DELIVERY_ACCEPTED: StringName = &"delivery_accepted"
const HIRE_ATTEMPTED: StringName = &"hire_attempted"
const LOAN_ATTEMPTED: StringName = &"loan_attempted"
const PURCHASE_ATTEMPTED: StringName = &"purchase_attempted"
## About to open sealed stock. Cancellable because "we do not rip our own inventory on a
## tournament night" is exactly the kind of house rule a shop has and a mod should be able
## to enforce.
const SEALED_OPEN_ATTEMPTED: StringName = &"sealed_open_attempted"

## name -> { kind, aggregate }. Everything the bus will accept.
const EVENTS: Dictionary = {
	SHIFT_STARTED: {"kind": Kind.NOTIFICATION},
	SHIFT_ENDED: {"kind": Kind.NOTIFICATION},
	DAY_ENDED: {"kind": Kind.NOTIFICATION},
	CUSTOMER_SPAWNED: {"kind": Kind.NOTIFICATION},
	CUSTOMER_SERVED: {"kind": Kind.NOTIFICATION},
	CUSTOMER_LEFT: {"kind": Kind.NOTIFICATION},
	VERIFICATION_RESOLVED: {"kind": Kind.NOTIFICATION},
	ORDER_TAKEN: {"kind": Kind.NOTIFICATION},
	ORDER_COMPLETED: {"kind": Kind.NOTIFICATION},
	ORDER_FAILED: {"kind": Kind.NOTIFICATION},
	GAME_RETURNED: {"kind": Kind.NOTIFICATION},
	COMPONENT_CHECK_RESOLVED: {"kind": Kind.NOTIFICATION},
	PACK_OPENED: {"kind": Kind.NOTIFICATION},
	CARD_GRADED: {"kind": Kind.NOTIFICATION},
	STRIKE_ISSUED: {"kind": Kind.NOTIFICATION},
	LICENCE_GRANTED: {"kind": Kind.NOTIFICATION},
	CAT_FED: {"kind": Kind.NOTIFICATION},
	CAT_REACTED: {"kind": Kind.NOTIFICATION},
	PEST_SIGHTED: {"kind": Kind.NOTIFICATION},
	STAFF_ERROR_MADE: {"kind": Kind.NOTIFICATION},
	MONEY_CHANGED: {"kind": Kind.NOTIFICATION},
	REPUTATION_CHANGED: {"kind": Kind.NOTIFICATION},
	PRICE_REQUESTED: {"kind": Kind.QUERY, "aggregate": Aggregate.PRODUCT},
	PATIENCE_MODIFIER_REQUESTED: {"kind": Kind.QUERY, "aggregate": Aggregate.PRODUCT},
	SPAWN_RATE_REQUESTED: {"kind": Kind.QUERY, "aggregate": Aggregate.PRODUCT},
	FORGERY_RATE_REQUESTED: {"kind": Kind.QUERY, "aggregate": Aggregate.PRODUCT},
	INSPECTION_TIME_REQUESTED: {"kind": Kind.QUERY, "aggregate": Aggregate.SUM},
	WAGE_REQUESTED: {"kind": Kind.QUERY, "aggregate": Aggregate.SUM},
	SALE_ATTEMPTED: {"kind": Kind.CANCELLABLE},
	TRADE_IN_ATTEMPTED: {"kind": Kind.CANCELLABLE},
	DELIVERY_ACCEPTED: {"kind": Kind.CANCELLABLE},
	HIRE_ATTEMPTED: {"kind": Kind.CANCELLABLE},
	LOAN_ATTEMPTED: {"kind": Kind.CANCELLABLE},
	PURCHASE_ATTEMPTED: {"kind": Kind.CANCELLABLE},
	SEALED_OPEN_ATTEMPTED: {"kind": Kind.CANCELLABLE},
}


static func is_known(event_name: StringName) -> bool:
	return EVENTS.has(event_name)


static func kind_of(event_name: StringName) -> Kind:
	var entry: Dictionary = EVENTS.get(event_name, {})
	return entry.get("kind", Kind.NOTIFICATION)


static func aggregate_of(event_name: StringName) -> Aggregate:
	var entry: Dictionary = EVENTS.get(event_name, {})
	return entry.get("aggregate", Aggregate.PRODUCT)


static func names() -> PackedStringArray:
	var out: PackedStringArray = []
	for event_name: StringName in EVENTS.keys():
		out.append(String(event_name))
	out.sort()
	return out
