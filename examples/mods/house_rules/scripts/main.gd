extends RefCounted

## House Rules: a policy the shop sets for itself, enforced the way the licensing board
## enforces its own -- through the same bus, with the same veto.
##
## This is the tier-3 test of the modding API: a mechanic that did not exist, added
## without touching a line of engine code.

const TRADE_IN_CEILING: float = 250.0

var api: ModApi
var taken_today: float = 0.0


func _enter_mod(p_api: ModApi) -> void:
	api = p_api
	api.on_attempt(EventCatalog.TRADE_IN_ATTEMPTED, _on_trade_in)
	api.on_attempt(EventCatalog.SALE_ATTEMPTED, _on_sale)
	api.on(EventCatalog.DAY_ENDED, _on_day_ended)
	api.on(EventCatalog.PATIENCE_MODIFIER_REQUESTED, _on_patience)


## A ceiling you set yourself, which staff must follow and you must remember you made.
func _on_trade_in(payload: Dictionary) -> String:
	var offer: float = absf(float(payload.get("value", 0.0)))
	if taken_today + offer > TRADE_IN_CEILING:
		return "house ceiling: %.0f already taken in today" % taken_today
	taken_today += offer
	return ""


func _on_sale(payload: Dictionary) -> String:
	if bool(payload.get("age_restricted", false)) and not bool(payload.get("id_verified", false)):
		return "house rule: everyone gets carded"
	return ""


func _on_day_ended(_payload: Dictionary) -> void:
	taken_today = 0.0


## Regulars are more patient in a shop that is visibly strict, because they know the
## queue is moving for a reason.
func _on_patience(_payload: Dictionary) -> float:
	return 1.08
