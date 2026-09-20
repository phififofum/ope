class_name EventBus
extends RefCounted

## The only permitted cross-system communication.
##
## Systems never hold references to one another; they publish and subscribe. Mod scripts
## get the same bus, the same event names and the same veto power that base systems have
## — that is not generosity, it is the test that the modding API is real.
##
## Every subscription is guarded: a handler that has gone stale (freed object, invalid
## callable) is dropped and reported rather than taking the game down with it.

## Emitted for every published event, in order. The event tracer and the telemetry log
## subscribe to this; nothing else should.
signal traced(event_name: StringName, payload: Dictionary, detail: Dictionary)


class Subscription:
	extends RefCounted
	var event_name: StringName
	var handler: Callable
	var owner_id: String
	var priority: int

	func _init(p_event: StringName, p_handler: Callable, p_owner: String, p_priority: int) -> void:
		event_name = p_event
		handler = p_handler
		owner_id = p_owner
		priority = p_priority


var _subscriptions: Dictionary = {}
var _errors: Array[String] = []
var _tracing: bool = false


## Subscribe [param handler] to [param event_name]. [param owner_id] names the mod or
## system, so a veto and an error can both say who was responsible. Lower [param priority]
## runs first; ties break on owner id, so the order never depends on load timing.
func subscribe(
	event_name: StringName, handler: Callable, owner_id: String = "base", priority: int = 0
) -> bool:
	if not EventCatalog.is_known(event_name):
		_errors.append("%s subscribed to unknown event '%s'" % [owner_id, event_name])
		return false
	if not handler.is_valid():
		_errors.append("%s subscribed an invalid handler to '%s'" % [owner_id, event_name])
		return false
	var list: Array = _subscriptions.get(event_name, [])
	list.append(Subscription.new(event_name, handler, owner_id, priority))
	list.sort_custom(_compare_subscriptions)
	_subscriptions[event_name] = list
	return true


func unsubscribe(event_name: StringName, handler: Callable) -> void:
	if not _subscriptions.has(event_name):
		return
	var kept: Array = []
	for subscription: Subscription in _subscriptions[event_name]:
		if subscription.handler != handler:
			kept.append(subscription)
	_subscriptions[event_name] = kept


## Drops every subscription owned by [param owner_id]. This is how a failing mod is
## disabled without restarting the game.
func unsubscribe_owner(owner_id: String) -> int:
	var removed: int = 0
	for event_name: StringName in _subscriptions.keys():
		var kept: Array = []
		for subscription: Subscription in _subscriptions[event_name]:
			if subscription.owner_id == owner_id:
				removed += 1
			else:
				kept.append(subscription)
		_subscriptions[event_name] = kept
	return removed


func subscriber_count(event_name: StringName) -> int:
	return (_subscriptions.get(event_name, []) as Array).size()


## Notification: something happened. Observers cannot change it.
func publish(event_name: StringName, payload: Dictionary = {}) -> void:
	if EventCatalog.kind_of(event_name) != EventCatalog.Kind.NOTIFICATION:
		_errors.append("'%s' published as a notification but is not one" % event_name)
	for subscription: Subscription in _live_subscriptions(event_name):
		subscription.handler.call(payload)
	_trace(event_name, payload, {})


## Query: observers contribute numbers, combined by the catalog's aggregator. The result
## cannot depend on subscription order, which is what "deterministically" means here.
func query(event_name: StringName, payload: Dictionary, base_value: float) -> float:
	var contributions: Array[float] = []
	for subscription: Subscription in _live_subscriptions(event_name):
		var contribution: Variant = subscription.handler.call(payload)
		if contribution is float or contribution is int:
			contributions.append(float(contribution))
		elif contribution != null:
			_errors.append(
				"%s contributed a non-numeric value to '%s'" % [subscription.owner_id, event_name]
			)
	var result: float = _aggregate(EventCatalog.aggregate_of(event_name), base_value, contributions)
	_trace(event_name, payload, {"base": base_value, "result": result})
	return result


## Cancellable: any observer may veto, with a reason. The first veto in priority order
## wins and the rest are not consulted — a refusal is a refusal.
func attempt(event_name: StringName, payload: Dictionary = {}) -> EventOutcome:
	if EventCatalog.kind_of(event_name) != EventCatalog.Kind.CANCELLABLE:
		_errors.append("'%s' attempted but is not cancellable" % event_name)
	for subscription: Subscription in _live_subscriptions(event_name):
		var verdict: Variant = subscription.handler.call(payload)
		if verdict is String and not (verdict as String).is_empty():
			var outcome := EventOutcome.veto(subscription.owner_id, verdict)
			_trace(event_name, payload, {"vetoed_by": outcome.vetoed_by, "reason": outcome.reason})
			return outcome
		if verdict is EventOutcome and not (verdict as EventOutcome).allowed:
			var typed: EventOutcome = verdict
			_trace(event_name, payload, {"vetoed_by": typed.vetoed_by, "reason": typed.reason})
			return typed
	_trace(event_name, payload, {"allowed": true})
	return EventOutcome.allow()


func set_tracing(enabled: bool) -> void:
	_tracing = enabled


func errors() -> Array[String]:
	return _errors.duplicate()


func clear_errors() -> void:
	_errors.clear()


func _trace(event_name: StringName, payload: Dictionary, detail: Dictionary) -> void:
	if _tracing:
		traced.emit(event_name, payload, detail)


## Returns live subscriptions, dropping any whose handler has become invalid — a mod
## whose object was freed must not take the next publish down with it.
func _live_subscriptions(event_name: StringName) -> Array:
	var list: Array = _subscriptions.get(event_name, [])
	var live: Array = []
	var stale: Array = []
	for subscription: Subscription in list:
		if subscription.handler.is_valid():
			live.append(subscription)
		else:
			stale.append(subscription)
	if not stale.is_empty():
		for subscription: Subscription in stale:
			_errors.append(
				(
					"dropped stale handler from %s on '%s'"
					% [subscription.owner_id, subscription.event_name]
				)
			)
		_subscriptions[event_name] = live
	return live


func _aggregate(mode: EventCatalog.Aggregate, base_value: float, values: Array[float]) -> float:
	var result: float = base_value
	match mode:
		EventCatalog.Aggregate.SUM:
			for value: float in values:
				result += value
		EventCatalog.Aggregate.PRODUCT:
			for value: float in values:
				result *= value
		EventCatalog.Aggregate.MIN:
			for value: float in values:
				result = minf(result, value)
		EventCatalog.Aggregate.MAX:
			for value: float in values:
				result = maxf(result, value)
	return result


func _compare_subscriptions(a: Subscription, b: Subscription) -> bool:
	if a.priority != b.priority:
		return a.priority < b.priority
	return a.owner_id < b.owner_id
