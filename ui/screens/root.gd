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
