extends Node

## The first thing that runs: load all content, then either report and exit, or open the
## front door.
##
## Keeping the headless report in the same place as the menu is deliberate. The check CI
## runs and the thing a player sees are the same code path, so a build that passes the
## smoke test is a build that boots.

const SMOKE_TEST_FLAG: String = "--smoke-test"
## Capture the real game to a PNG and exit. This is the visual regression harness's
## camera: fixed seed, fixed frame, fixed camera position, so a diff against an approved
## baseline means a render changed rather than a shift went differently.
const SCREENSHOT_FLAG: String = "--screenshot"
const SCREENSHOT_FRAMES: int = 60
## Run the bot across player counts, presets and seeds, and print the result as JSON.
## This is the nightly probe: it answers whether a campaign can be completed, whether
## anything soft-locks, and whether the economy reaches a dead end.
const BOT_FLAG: String = "--bot"

var settings: GameSettings
var menu: MainMenu
var session: GameSession

var _report: ContentLoader.LoadReport


func _ready() -> void:
	settings = GameSettings.load_from_disk()
	_report = Game.boot()
	print(_startup_report())

	if OS.get_cmdline_user_args().has(SMOKE_TEST_FLAG):
		get_tree().quit(1 if not _report.errors().is_empty() else 0)
		return
	if OS.get_cmdline_user_args().has(BOT_FLAG):
		get_tree().quit(_run_bot_sweep())
		return
	if DisplayServer.get_name() == "headless":
		return

	var shot_path: String = _argument_after(SCREENSHOT_FLAG)
	if not shot_path.is_empty():
		_capture(shot_path)
		return

	_open_menu()


## Runs the game for a fixed number of frames with a fixed seed, then writes what it
## looks like. Everything about it is deterministic on purpose.
func _capture(path: String) -> void:
	_start_session(20260920)
	await get_tree().process_frame
	# A scheduled beat, so the shot always contains the same thing: somebody at the
	# counter with a document in the player's hands. The shift is fast-forwarded rather
	# than waited out -- the simulation runs on ticks, so this is the same state a player
	# would reach, just sooner.
	for _tick: int in range(2000):
		session.shop.tick()
		if not session.shop.waiting_encounters.is_empty():
			break
	session.world.sync_customers()
	session.hud.set_hands("northvale id", "uv torch")

	# Two shots, because they fail differently: the room catches lighting, materials and
	# layout regressions, and the counter catches the document renderer -- which is the
	# one the player spends the game staring at.
	for _frame: int in range(SCREENSHOT_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_write_image(path.get_basename() + "_room.png")

	# The back office, which is where the campaign actually lives: licences, equipment,
	# staff, the ledger and the deeds. A third shot because it fails differently again --
	# an empty page here means content the player cannot reach.
	session.management.toggle()
	for _frame: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_write_image(path.get_basename() + "_office.png")
	session.management.toggle()
	for _frame: int in range(4):
		await get_tree().process_frame

	session._serve_next()
	for _frame: int in range(12):
		await get_tree().process_frame
	for _frame: int in range(6):
		await get_tree().process_frame
	if _argument_after("--debug-layout") == "yes":
		_print_layout(get_tree().root, 0)
	await RenderingServer.frame_post_draw
	var ok: bool = _write_image(path)
	get_tree().quit(0 if ok else 1)


func _write_image(path: String) -> bool:
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error: Error = image.save_png(path)
	print("screenshot: %s (%s)" % [path, "ok" if error == OK else str(error)])
	return error == OK


func _print_layout(node: Node, depth: int) -> void:
	var rect: String = ""
	if node is Control:
		var control: Control = node
		rect = " rect=%s size=%s vis=%s" % [control.global_position, control.size, control.visible]
	print("%s%s (%s)%s" % ["  ".repeat(depth), node.name, node.get_class(), rect])
	for child: Node in node.get_children():
		if depth < 4:
			_print_layout(child, depth + 1)


func _argument_after(flag: String) -> String:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = arguments.find(flag)
	if index < 0 or index + 1 >= arguments.size():
		return ""
	return arguments[index + 1]


## The nightly sweep. Deliberately unglamorous: it is a liveness and progression probe,
## not a demonstration of skill.
func _run_bot_sweep() -> int:
	var days: int = (
		int(_argument_after("--days")) if not _argument_after("--days").is_empty() else 10
	)
	var seed_count: int = (
		int(_argument_after("--seeds")) if not _argument_after("--seeds").is_empty() else 3
	)
	var presets: PackedStringArray = (
		PackedStringArray([_argument_after("--preset")])
		if not _argument_after("--preset").is_empty()
		else PackedStringArray(["relaxed", "standard", "tight", "brutal"])
	)
	var counts: PackedStringArray = (
		PackedStringArray([_argument_after("--players")])
		if not _argument_after("--players").is_empty()
		else PackedStringArray(["1", "2", "3", "4", "5"])
	)
	var policy: BotPlayer.Policy = _policy_named(_argument_after("--policy"))

	var runs: Array[Dictionary] = []
	var failures: int = 0
	for preset: String in presets:
		for players_text: String in counts:
			for seed_index: int in range(seed_count):
				var seed_value: int = 1000 + seed_index * 97
				var players: int = int(players_text)
				var bus := EventBus.new()
				var shop := Shop.new(
					Game.registry,
					bus,
					SeededRng.new(seed_value),
					Director.Profile.preset(preset),
					players
				)
				var telemetry := RunLog.new(bus, seed_value, preset, players)
				shop.open_for_business(600.0)
				var report: Dictionary = BotPlayer.new(shop, policy, telemetry).play(days)

				var run: Dictionary = {
					"preset": preset,
					"players": players,
					"seed": seed_value,
					"days": report["days"],
					"soft_lock_ticks": report["soft_lock_ticks"],
					"insolvent": report["insolvent"],
					"money": report["final_money"],
					"case_value": shop.card_case.case_value(),
					"stock_value": report["stock_value"],
					# The honest sealed number, per run: a sweep is the only place the
					# long-run return on cardboard can be looked at without playing it.
					"sealed": report["sealed"],
					"reputation": report["final_reputation"],
					"licences": shop.economy.licences.size(),
					"staff": shop.staff.employees.size(),
					"act": shop.act(),
					"verdicts": report["verdicts"],
					# Where the reputation went, by reason: the question "why is the shop
					# hated" should be answerable from the log, not from a hunch.
					"reputation_by_reason": _reputation_breakdown(shop),
					"counters": telemetry.summary()["counters"],
					"outcomes": telemetry.summary()["outcomes"],
				}
				# A soft lock or an insolvency is the thing this exists to find.
				if int(run["soft_lock_ticks"]) > 0 or bool(run["insolvent"]):
					failures += 1
				runs.append(run)

	var output: Dictionary = {"runs": runs, "failures": failures, "policy": _policy_name(policy)}
	var path: String = _argument_after("--out")
	if not path.is_empty():
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(output, "  "))
			file.close()
	print(JSON.stringify(output))
	return 1 if failures > 0 else 0


func _policy_name(policy: BotPlayer.Policy) -> String:
	return ["balanced", "counter_first", "kitchen_first", "careless", "paranoid", "gambler"][policy]


func _policy_named(name: String) -> BotPlayer.Policy:
	match name:
		"careless":
			return BotPlayer.Policy.CARELESS
		"paranoid":
			return BotPlayer.Policy.PARANOID
		"counter_first":
			return BotPlayer.Policy.COUNTER_FIRST
		"kitchen_first":
			return BotPlayer.Policy.KITCHEN_FIRST
		"gambler":
			return BotPlayer.Policy.GAMBLER
		_:
			return BotPlayer.Policy.BALANCED


func _reputation_breakdown(shop: Shop) -> Dictionary:
	var by_reason: Dictionary = {}
	for entry: Dictionary in shop.economy.ledger():
		if str(entry.get("kind", "")) != "reputation":
			continue
		var reason: String = str(entry.get("reason", "?"))
		by_reason[reason] = snappedf(
			float(by_reason.get(reason, 0.0)) + float(entry["amount"]), 0.01
		)
	return by_reason


func _open_menu() -> void:
	if session != null:
		session.queue_free()
		session = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = MainMenu.new()
	add_child(menu)
	menu.setup(settings)
	menu.play_requested.connect(_start_session)
	menu.rush_requested.connect(_start_rush)
	menu.settings_requested.connect(_open_settings)
	menu.quit_requested.connect(func() -> void: get_tree().quit())


func _open_settings() -> void:
	var screen := SettingsMenu.new()
	add_child(screen)
	screen.setup(settings)
	screen.closed.connect(
		func() -> void:
			screen.queue_free()
			if menu != null:
				menu.apply_settings_scale()
	)


func _start_session(session_seed: int) -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	session = GameSession.new()
	add_child(session)
	session.start(settings, session_seed, 1)


## Rush mode runs the kitchen alone. Here it is driven by the same serve policy the bot
## uses, so a player can watch it or take over; the campaign is where the collision lives.
func _start_rush() -> void:
	if menu != null:
		menu.set_status("Rush mode: the kitchen, escalating, until the queue wins.")
	var rush := RushMode.new(Game.registry, Game.bus, SeededRng.new(randi()))
	var serve := func(kitchen: Kitchen, now: int) -> void:
		for order: Kitchen.Order in kitchen.pending_orders():
			if order.state == Kitchen.OrderState.WAITING:
				kitchen.start_order(order, now)
				return
			if order.state == Kitchen.OrderState.READY:
				kitchen.serve(order, rush.economy)
				return
	while rush.play_day(serve):
		var offered: Array = rush.offer_upgrades()
		if offered.is_empty():
			break
		rush.take_upgrade(offered[0])
	if menu != null:
		menu.set_status(
			(
				"Rush: survived %d days, served %d, %s"
				% [rush.run.day, rush.run.served, rush.run.ended_because]
			)
		)


func _startup_report() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	var lines: PackedStringArray = []
	lines.append("PoggyWoggy %s" % version)
	lines.append("content sources: %s" % ", ".join(_report.sources))
	for type_name: StringName in Game.registry.types():
		lines.append("  %4d  %s" % [Game.registry.count_of(type_name), type_name])
	lines.append("  %4d  definitions total" % Game.registry.size())
	for override: Dictionary in Game.registry.overrides():
		lines.append(
			(
				"  override  %s: %s wins over %s"
				% [override["id"], override["winning_source"], override["overridden_source"]]
			)
		)
	for issue: ValidationIssue in _report.issues:
		lines.append("  " + issue.to_text())
	for source_id: String in _report.disabled_sources.keys():
		lines.append("  DISABLED  %s: %s" % [source_id, _report.disabled_sources[source_id]])
	return "\n".join(lines)
