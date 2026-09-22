class_name ManagementScreen
extends Control

## The back office: everything the shop owns, everything it could buy, and how the
## campaign is going.
##
## The game shipped with roughly a thousand content definitions -- licences, equipment,
## staff roles, cats, achievements -- that the simulation consumed and the player could
## never see or choose. That is the difference between a game and a simulation with a
## viewport, and this screen is the fix: every one of those definitions is reachable
## here, priced, and either bought or explained.
##
## Opened with Tab, and it pauses nothing: the shift runs while you shop, because
## deciding what to spend money on while the queue builds is the game.

signal closed

enum Page { LICENCES, EQUIPMENT, STAFF, CATS, LEDGER, DEEDS }

const PAGE_NAMES: Array[String] = [
	"Licences", "Equipment", "Staff", "Cats", "Ledger", "Book of Deeds"
]

var shop: Shop
var log: RunLog

var _page: Page = Page.LICENCES
var _tabs: HBoxContainer
var _list: VBoxContainer
var _header: Label
var _footer: Label
var _settings: GameSettings


func setup(p_shop: Shop, p_log: RunLog, p_settings: GameSettings) -> void:
	shop = p_shop
	log = p_log
	_settings = p_settings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.04, 0.06, 0.93)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 64)
	frame.add_theme_constant_override("margin_right", 64)
	frame.add_theme_constant_override("margin_top", 40)
	frame.add_theme_constant_override("margin_bottom", 72)
	add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(column)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 30)
	column.add_child(_header)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	column.add_child(_tabs)
	for index: int in range(PAGE_NAMES.size()):
		var button := Button.new()
		button.text = "%d  %s" % [index + 1, PAGE_NAMES[index]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_show_page.bind(index as Page))
		_tabs.add_child(button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 15)
	_footer.modulate = Color(0.75, 0.75, 0.8)
	_footer.text = "1–6 to switch pages · Tab or Esc to get back to the shop"
	column.add_child(_footer)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()
	else:
		closed.emit()


## Rebuilds the current page from the registry. Cheap enough to do on every open, and
## doing it that way means the page can never be stale.
func refresh() -> void:
	if shop == null:
		return
	_header.text = (
		"Day %d   ·   %s   ·   reputation %.1f   ·   standing %d"
		% [shop.day, _money(shop.economy.money), shop.economy.reputation, shop.economy.standing]
	)
	for index: int in range(_tabs.get_child_count()):
		var button: Button = _tabs.get_child(index)
		button.modulate = Color.WHITE if index == int(_page) else Color(0.62, 0.62, 0.68)

	for child: Node in _list.get_children():
		child.queue_free()

	match _page:
		Page.LICENCES:
			_fill_licences()
		Page.EQUIPMENT:
			_fill_equipment()
		Page.STAFF:
			_fill_staff()
		Page.CATS:
			_fill_cats()
		Page.LEDGER:
			_fill_ledger()
		Page.DEEDS:
			_fill_deeds()


func handle_key(keycode: int) -> bool:
	if not visible:
		return false
	if keycode >= KEY_1 and keycode <= KEY_6:
		_show_page((keycode - KEY_1) as Page)
		return true
	return false


# --- the pages -------------------------------------------------------------------


## What you may legally sell, and what each licence drags in with it. The obligations are
## listed because a licence that only costs money is a shopping list entry, not a choice.
func _fill_licences() -> void:
	_note(
		(
			"A licence is permission and paperwork in one. Everything it unlocks becomes"
			+ " sellable; everything it obliges becomes something an inspector can find."
		)
	)
	var licences: Array = shop.registry.by_type(&"licence")
	licences.sort_custom(
		func(a: ContentDefinition, b: ContentDefinition) -> bool:
			return a.get_number("cost") < b.get_number("cost")
	)
	for licence: ContentDefinition in licences:
		var held: bool = shop.economy.holds(licence.id)
		var standing: int = int(licence.get_number("standing_required", 0))
		var cost: float = licence.get_number("cost")
		var burden: Array = licence.get_value("verification_burden", [])
		var unlocks: Array = (
			licence.get_value("unlocks_categories", [])
			+ licence.get_value("unlocks_activities", [])
		)
		var sells: String = (
			"sell %s" % ", ".join(PackedStringArray(unlocks)).replace("_", " ")
			if not unlocks.is_empty()
			else "permission to trade"
		)
		var detail: String = (
			"%s  ·  brings: %s" % [sells, ", ".join(PackedStringArray(burden))]
			if not burden.is_empty()
			else sells
		)
		var reason: String = ""
		if held:
			reason = "held"
		elif shop.economy.standing < standing:
			reason = "needs standing %d, you have %d" % [standing, shop.economy.standing]
		elif shop.economy.money < cost:
			reason = "costs %s" % _money(cost)
		_row(
			_title(licence),
			"%s  ·  %s" % [_money(cost), detail],
			reason,
			held or shop.economy.standing < standing or shop.economy.money < cost,
			func() -> void:
				if shop.buy_licence(licence.id):
					refresh()
		)


## Equipment. Each one is a permanent discount on the seconds a kind of work costs, which
## is the only thing in this game that is genuinely scarce.
func _fill_equipment() -> void:
	_note(
		(
			"Every task in the shift is priced in seconds the queue is not waiting through."
			+ " Equipment buys those seconds back, permanently."
		)
	)
	var upgrades: Array = shop.registry.by_type(&"upgrade")
	upgrades.sort_custom(
		func(a: ContentDefinition, b: ContentDefinition) -> bool:
			return a.get_number("cost") < b.get_number("cost")
	)
	for upgrade: ContentDefinition in upgrades:
		var owned: bool = shop.owned_upgrades.has(String(upgrade.id))
		var missing: PackedStringArray = []
		for prerequisite: String in upgrade.get_value("prerequisites", []):
			if not shop.owned_upgrades.has(prerequisite):
				missing.append(prerequisite.replace("base:", "").replace("_", " "))
		var cost: float = upgrade.get_number("cost")
		var removes: String = upgrade.get_text("removes_step", "")
		var reason: String = ""
		if owned:
			reason = "installed"
		elif not missing.is_empty():
			reason = "needs %s" % ", ".join(missing)
		elif shop.economy.money < cost:
			reason = "costs %s" % _money(cost)
		_row(
			_title(upgrade),
			(
				"%s  ·  %s  ·  %s"
				% [
					_money(cost),
					upgrade.get_text("category"),
					("removes %s" % removes) if not removes.is_empty() else "makes the work quicker"
				]
			),
			reason,
			owned or not missing.is_empty() or shop.economy.money < cost,
			func() -> void:
				if shop.buy_upgrade(upgrade.id):
					refresh()
		)


## Hiring. The applicant is generated when you ask, because who turns up is itself a
## verification problem -- and the references are never checked unless you check them.
func _fill_staff() -> void:
	_note(
		(
			"Hiring is a verification encounter with a wage attached. Nobody's references are"
			+ " checked unless you audit them, and the cost of not doing so arrives later."
		)
	)
	for employee: StaffSystem.Employee in shop.staff.employees:
		_row(
			employee.display_name,
			(
				"%s  ·  trained %.0f%%  ·  morale %.0f%%  ·  %s"
				% [
					String(employee.role_id).replace("base:", "").replace("_", " "),
					employee.training * 100.0,
					employee.morale * 100.0,
					(
						"%d permission(s)" % employee.permissions.size()
						if not employee.permissions.is_empty()
						else "no permissions yet"
					)
				]
			),
			"on the books",
			true,
			func() -> void: pass
		)
	for role: ContentDefinition in shop.registry.by_type(&"staff_role"):
		var wage: float = role.get_number("wage_per_shift")
		_row(
			_title(role),
			"%s a shift  ·  %s" % [_money(wage), role.get_text("description", "")],
			"" if shop.economy.money > wage * 6.0 else "keep a float: %s a shift" % _money(wage),
			shop.economy.money <= wage * 6.0,
			func() -> void:
				var applicant: StaffSystem.Employee = shop.interview(role.id)
				shop.hire(applicant, shop.players[0], shop.clock.current_tick())
				refresh()
		)


func _fill_cats() -> void:
	_note(
		(
			"A cat is a pest control system with opinions. It keeps the mice down, it reacts"
			+ " to the people at the counter, and it will sit on whatever you are reading."
		)
	)
	for cat: CatSystem.Cat in shop.cats.residents:
		_row(
			cat.given_name,
			(
				"in residence  ·  %s  ·  affection %.0f%%"
				% [
					String(cat.definition_id).replace("base:", "").replace("_", " "),
					cat.affection * 100.0
				]
			),
			"yours",
			true,
			func() -> void: pass
		)
	for cat_definition: ContentDefinition in shop.registry.by_type(&"cat"):
		var already: bool = false
		for resident: CatSystem.Cat in shop.cats.residents:
			already = already or resident.definition_id == cat_definition.id
		if already:
			continue
		_row(
			_title(cat_definition),
			(
				"%s coat  ·  hunts %.0f%%  ·  %s"
				% [
					cat_definition.get_text("coat", "tabby"),
					cat_definition.get_number("base_hunting", 0.5) * 100.0,
					_strongest_trait(cat_definition)
				]
			),
			"",
			false,
			func() -> void:
				shop.cats.adopt(cat_definition.id)
				refresh()
		)


## The books. Where the money went, and the one number the design promised never to hide.
func _fill_ledger() -> void:
	var sealed: Dictionary = shop.card_case.sealed_ledger()
	_note(
		(
			"Cash %s  ·  stock %s  ·  case %s"
			% [
				_money(shop.economy.money),
				_money(shop.inventory.stock_value()),
				_money(shop.card_case.case_value())
			]
		)
	)
	if int(sealed["units_ripped"]) > 0:
		_row(
			"Sealed product, lifetime",
			(
				"%d opened, worth %s on the shelf  ·  came back %s"
				% [
					int(sealed["units_ripped"]),
					_money(float(sealed["retail_forgone"])),
					_money(float(sealed["realised"]) + float(sealed["unsold_value"]))
				]
			),
			"%d%% return" % int(round(float(sealed["return_ratio"]) * 100.0)),
			true,
			func() -> void: pass
		)
	var by_reason: Dictionary = {}
	for entry: Dictionary in shop.economy.ledger():
		if str(entry.get("kind", "")) == "reputation":
			continue
		var reason: String = str(entry.get("reason", "?"))
		by_reason[reason] = float(by_reason.get(reason, 0.0)) + float(entry["amount"])
	var reasons: Array = by_reason.keys()
	reasons.sort_custom(
		func(a: String, b: String) -> bool: return absf(by_reason[a]) > absf(by_reason[b])
	)
	for reason: String in reasons.slice(0, 24):
		var amount: float = by_reason[reason]
		_row(reason, "", _money(amount), true, func() -> void: pass)


## Sixty achievements ship in content. They were counted by nothing and shown nowhere;
## the telemetry log already counts every event they ask about, so they are simply read
## off it.
func _fill_deeds() -> void:
	_note("What the shop has done so far. Progress comes from the run's own event log.")
	var earned: int = 0
	var rows: Array = []
	for deed: ContentDefinition in shop.registry.by_type(&"achievement"):
		var condition: Dictionary = deed.get_value("condition", {})
		var event: String = str(condition.get("event", ""))
		var target: int = maxi(1, int(condition.get("count", 1)))
		var progress: int = 0 if log == null else int(log.counters.get(event, 0))
		var done: bool = progress >= target
		earned += 1 if done else 0
		if bool(deed.get_value("hidden", false)) and not done:
			rows.append(["A hidden deed", "keep playing", "", false])
			continue
		rows.append(
			[
				_title(deed),
				"%s  ·  %d of %d" % [event.replace("_", " "), mini(progress, target), target],
				"done" if done else "",
				done
			]
		)
	_note("%d of %d earned" % [earned, rows.size()])
	for row: Array in rows:
		_row(row[0], row[1], row[2], true, func() -> void: pass)


# --- furniture -------------------------------------------------------------------


func _show_page(page: Page) -> void:
	_page = page
	refresh()


## One entry: what it is, what it costs, and either a button or the reason there is not
## one. A greyed-out row that does not say why is the thing that makes a menu feel shut.
func _row(
	title: String, detail: String, status: String, disabled: bool, on_press: Callable
) -> void:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 0.85) if disabled else Color(0.14, 0.16, 0.2, 0.9)
	style.border_color = Color(0.3, 0.32, 0.38)
	style.set_border_width_all(1)
	style.set_content_margin_all(9)
	style.set_corner_radius_all(3)
	row.add_theme_stylebox_override("panel", style)
	_list.add_child(row)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)

	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.modulate = Color(0.72, 0.74, 0.78) if disabled else Color.WHITE
	text.add_child(name_label)

	if not detail.is_empty():
		var detail_label := Label.new()
		detail_label.text = detail
		detail_label.add_theme_font_size_override("font_size", 14)
		detail_label.modulate = Color(0.68, 0.7, 0.74)
		text.add_child(detail_label)

	if disabled:
		if not status.is_empty():
			var status_label := Label.new()
			status_label.text = status
			status_label.add_theme_font_size_override("font_size", 14)
			status_label.modulate = (
				Color(0.6, 0.68, 0.6) if status == "held" else Color(0.7, 0.66, 0.6)
			)
			line.add_child(status_label)
		return

	var button := Button.new()
	button.text = "Buy" if status.is_empty() else status
	button.custom_minimum_size = Vector2(110.0, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	line.add_child(button)


## What a cat is mostly like, from the weights it ships with. "Nocturnal" tells you more
## about living with it than a number does.
func _strongest_trait(cat_definition: ContentDefinition) -> String:
	var weights: Dictionary = cat_definition.get_value("trait_weights", {})
	var best: String = ""
	var best_weight: float = 0.0
	for trait_name: String in weights.keys():
		if float(weights[trait_name]) > best_weight:
			best_weight = float(weights[trait_name])
			best = trait_name
	return best.replace("_", " ")


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = Color(0.66, 0.68, 0.74)
	_list.add_child(label)


## Content names are loc: keys; until the localisation pass there is no table to look
## them up in, so they are turned back into words here rather than shown raw.
func _title(definition: ContentDefinition) -> String:
	var key: String = definition.get_text("name", "")
	if key.is_empty():
		key = String(definition.id)
	var readable: String = key.get_slice(".", key.get_slice_count(".") - 1)
	return readable.replace("_", " ").capitalize()


## The shop is somewhere with trading standards and a waste licence, so the money has a
## pound sign on it.
func _money(amount: float) -> String:
	return "%s£%.2f" % ["-" if amount < 0.0 else "", absf(amount)]
