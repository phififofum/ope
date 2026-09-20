class_name GameSession
extends Node3D

## Where the simulation and the room meet.
##
## The shop runs on its own fixed clock whatever the framerate; this node feeds it real
## time, turns player interactions into the same actions the bot uses, and translates
## what happens back into prompts, cues and subtitles.

signal day_ended(summary: Dictionary)
signal encounter_presented(encounter: Encounter)

var settings: GameSettings
var shop: Shop
var world: ShopWorld
var hud: Hud
var inspection: InspectionView
var log: RunLog

var current_encounter: Encounter
var _clock := TickScheduler.new()
var _free_slot: Shop.PlayerSlot


func start(p_settings: GameSettings, session_seed: int = 0, player_count: int = 1) -> void:
	settings = p_settings
	var registry: ContentRegistry = Game.registry
	var bus: EventBus = Game.bus
	var rng := SeededRng.new(session_seed)

	shop = Shop.new(
		registry, bus, rng, Director.Profile.preset(settings.difficulty_preset), player_count
	)
	shop.open_for_business(600.0)
	log = RunLog.new(bus, session_seed, settings.difficulty_preset, player_count)

	world = ShopWorld.new()
	add_child(world)
	world.build(shop)
	world.player.look_sensitivity = PlayerController.MOUSE_SENSITIVITY * settings.look_sensitivity
	world.player.invert_y = settings.invert_look_y
	world.player.head_bob_enabled = settings.head_bob
	world.player.camera().fov = settings.field_of_view
	world.player.looked_at.connect(_on_looked_at)

	hud = Hud.new()
	add_child(hud)
	hud.setup(settings)

	# Controls need a CanvasLayer to lay out against the viewport: parented to a Node3D
	# they have no rect, and anchors resolve to nothing.
	var overlay := CanvasLayer.new()
	overlay.layer = 9
	add_child(overlay)
	inspection = InspectionView.new()
	overlay.add_child(inspection)
	inspection.setup(settings, registry)
	inspection.verdict_chosen.connect(_on_verdict_chosen)

	_free_slot = shop.players[0]
	_connect_cues(bus)
	shop.start_day(1)
	hud.say("", "You have inherited the place. The previous owner left notes.")


func _process(delta: float) -> void:
	if shop == null:
		return
	var ticks: int = _clock.advance(delta)
	for _index: int in range(ticks):
		shop.tick()
	if ticks > 0:
		world.sync_customers()
	if _clock.current_tick() % 600 == 0 and log != null:
		log.sample(shop.day, shop.clock.current_tick(), shop.state_sample())
	if shop.clock.current_tick() - shop.day * Shop.DAY_TICKS > Shop.DAY_TICKS:
		var summary: Dictionary = shop.end_day()
		day_ended.emit(summary)
		shop.start_day(shop.day + 1)


func _unhandled_input(event: InputEvent) -> void:
	if shop == null or not event.is_pressed():
		return
	if event.is_action("interact"):
		_interact()
	elif event.is_action("use_tool") and inspection.visible:
		_reach_for_nearest_tool()
	elif event.is_action("open_binder"):
		_show_binder()


## One interaction verb, and what it does depends entirely on what you are standing in
## front of. There is no menu of available actions.
func _interact() -> void:
	var target: Node3D = world.player.current_target()
	var interactable: Interactable = target as Interactable
	if interactable == null:
		return
	var now: int = shop.clock.current_tick()
	match interactable.kind:
		Interactable.Kind.COUNTER:
			_serve_next()
		Interactable.Kind.KITCHEN_STATION:
			if not shop.run_food(_free_slot, now):
				shop.cook_next(_free_slot, now)
		Interactable.Kind.LIBRARY_SHELF:
			var result: Dictionary = shop.check_next_return(_free_slot, now)
			if not result.is_empty():
				var complete: bool = bool(result.get("complete", true))
				hud.cue(
					"component check: %s" % ("complete" if complete else "pieces missing"),
					"good" if complete else "warning"
				)
		Interactable.Kind.RETAIL_SHELF:
			shop.restock_shelves(_free_slot, now)
		Interactable.Kind.CASE:
			var case_result: Dictionary = shop.work_the_case(_free_slot, now, 20.0)
			hud.cue("case: %d sold" % int(case_result.get("sold", 0)), "info")
		Interactable.Kind.TABLE:
			shop.clean_up(_free_slot, now, interactable.seconds)
		_:
			shop.clean_up(_free_slot, now, interactable.seconds)


func _serve_next() -> void:
	if shop.waiting_encounters.is_empty():
		hud.set_prompt("nobody at the counter")
		return
	current_encounter = shop.waiting_encounters[0]
	inspection.present(current_encounter, PackedStringArray(["base:naked_eye"]))
	encounter_presented.emit(current_encounter)

	var tell: String = current_encounter.person.tell()
	if not tell.is_empty():
		hud.say(current_encounter.person.display_name, tell)
	if settings.memory_assist:
		hud.show_active_rules(_active_rule_names(current_encounter))


## The rules that apply to what is on the counter right now. Generated from the same
## definitions that enforce them, so the assist cannot drift from the game.
func _active_rule_names(encounter: Encounter) -> PackedStringArray:
	var names: PackedStringArray = []
	var artifact: Artifact = encounter.primary_artifact()
	if artifact == null:
		return names
	for rule: ContentDefinition in shop.verification.rules.applicable_rules(
		artifact, encounter.transaction_tags
	):
		names.append(rule.get_text("name").replace("loc:rule.", "").replace("_", " "))
	return names


func _reach_for_nearest_tool() -> void:
	for tool_id: String in shop.owned_tools:
		if not inspection.tools_in_hand().has(tool_id):
			inspection.use_tool(tool_id)
			hud.set_hands("document", tool_id.replace("base:", ""))
			return


func _on_verdict_chosen(verdict: int) -> void:
	if current_encounter == null:
		return
	var tools: PackedStringArray = inspection.tools_in_hand()
	var result: Dictionary = shop.serve_counter(
		_free_slot, verdict, tools, shop.clock.current_tick()
	)
	inspection.put_down()
	current_encounter = null
	if result.is_empty():
		return
	# Consequence, not a score: some verdicts resolve now and some arrive as a fine on
	# Thursday, so the feedback here is about what happened, never about whether you were
	# clever.
	var outcome: int = int(result.get("outcome", 0))
	match outcome:
		Encounter.Outcome.CORRECT:
			hud.cue("handled", "good")
		Encounter.Outcome.WRONG_APPROVED:
			hud.cue("that one was wrong", "bad")
		_:
			hud.cue("they were who they said they were", "warning")


func _show_binder() -> void:
	# The binder is generated from the same definitions that drive the rules, so it can
	# never be out of date -- and mod-added rules appear in it with no extra work.
	var entries: PackedStringArray = []
	for rule: ContentDefinition in Game.registry.by_type(&"rule"):
		entries.append(rule.get_text("name").replace("loc:rule.", "").replace("_", " "))
	hud.show_active_rules(entries)
	hud.say("", "You open the binder. It costs you seconds you do not have.")


func _on_looked_at(target: Node3D) -> void:
	var interactable: Interactable = target as Interactable
	hud.set_prompt("" if interactable == null else interactable.prompt_text())


func _connect_cues(bus: EventBus) -> void:
	# Audio is a gameplay signal here; every one of these has a visible equivalent for
	# players who cannot rely on hearing it.
	bus.subscribe(
		EventCatalog.CUSTOMER_SPAWNED,
		func(_p: Dictionary) -> void: hud.cue("door chime", "info", "front"),
		"hud"
	)
	bus.subscribe(
		EventCatalog.ORDER_TAKEN,
		func(_p: Dictionary) -> void: hud.cue("ticket printed", "info", "kitchen"),
		"hud"
	)
	bus.subscribe(
		EventCatalog.ORDER_FAILED,
		func(p: Dictionary) -> void:
			hud.cue(str(p.get("reason", "order failed")), "bad", "kitchen"),
		"hud"
	)
	bus.subscribe(
		EventCatalog.PEST_SIGHTED,
		func(_p: Dictionary) -> void: hud.cue("something moved by the bins", "warning", "back"),
		"hud"
	)
	bus.subscribe(
		EventCatalog.CAT_REACTED,
		func(p: Dictionary) -> void: hud.cue("%s is staring" % p.get("cat", "the cat"), "warning"),
		"hud"
	)
	bus.subscribe(
		EventCatalog.STRIKE_ISSUED,
		func(p: Dictionary) -> void: hud.cue("strike: %s" % p.get("reason", ""), "bad"),
		"hud"
	)
