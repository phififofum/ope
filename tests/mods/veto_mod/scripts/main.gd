extends RefCounted

## Fixture mod script. It vetoes any sale of an age-restricted product to a customer the
## payload marks as unverified — which is the Phase 1 gate: a mod changing a gameplay
## outcome through the public API, with no engine code changed.

var api: ModApi


func _enter_mod(p_api: ModApi) -> void:
	api = p_api
	api.on_attempt(EventCatalog.SALE_ATTEMPTED, _on_sale_attempted)
	api.on(EventCatalog.PRICE_REQUESTED, _on_price_requested)
	(
		api
		. define(
			{
				"id": "veto_mod:runtime_defined_tool",
				"type": "tool",
				"name": "loc:veto_mod.tool.runtime_defined_tool",
				"tier": 1,
				"reveals": ["runtime_marker"],
				"inspection_seconds": 1.0,
				"unlocked_by": "start",
				"returns_verdict": false,
			}
		)
	)


func _on_sale_attempted(payload: Dictionary) -> String:
	if bool(payload.get("age_restricted", false)) and not bool(payload.get("id_verified", false)):
		return "no ID on an age-restricted sale"
	return ""


func _on_price_requested(_payload: Dictionary) -> float:
	return 1.10
