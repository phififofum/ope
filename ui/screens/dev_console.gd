class_name DevConsole
extends CanvasLayer

## The in-game console, and the event tracer behind it.
##
## This is the difference between a modding feature and a modding ecosystem: being able
## to ask the running game what it loaded, what it is doing, and why your definition is
## not showing up -- without a debugger, and without a restart.

const HISTORY_LINES: int = 220

var registry: ContentRegistry
var bus: EventBus

var _output: RichTextLabel
var _input: LineEdit
var _tracing: bool = false
var _trace_filter: String = ""


func setup(p_registry: ContentRegistry, p_bus: EventBus) -> void:
	registry = p_registry
	bus = p_bus
	layer = 50

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.5
	add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)

	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_following = true
	_output.custom_minimum_size = Vector2(0.0, 300.0)
	column.add_child(_output)

	_input = LineEdit.new()
	_input.placeholder_text = "help"
	_input.text_submitted.connect(_on_submitted)
	column.add_child(_input)

	bus.traced.connect(_on_traced)
	visible = false
	_print("PoggyWoggy console. Type `help`.")


func toggle() -> void:
	visible = not visible
	if visible:
		_input.grab_focus()


func _on_submitted(line: String) -> void:
	_input.text = ""
	_print("[color=#8ab4f8]> %s[/color]" % line)
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var command: String = parts[0]
	var argument: String = " ".join(parts.slice(1))

	match command:
		"help":
			_print(
				"""commands:
  types                    what loaded, by type
  list <type> [tag]        ids of a type, optionally filtered by tag
  show <id>                one definition, in full
  find <text>              any id containing text
  mods                     content sources, and which override won
  events                   the event catalogue
  trace [on|off|<name>]    watch events as they fire
  reload                   reload all content from disk"""
			)
		"types":
			for type_name: StringName in registry.types():
				_print("  %4d  %s" % [registry.count_of(type_name), type_name])
		"list":
			_list(argument)
		"show":
			var definition: ContentDefinition = registry.get_definition(StringName(argument))
			if definition == null:
				_print("no definition '%s'" % argument)
			else:
				_print(JSON.stringify(definition.data, "  "))
		"find":
			var matches: int = 0
			for type_name: StringName in registry.types():
				for definition: ContentDefinition in registry.by_type(type_name):
					if String(definition.id).contains(argument):
						_print(
							"  %s  (%s, from %s)" % [definition.id, type_name, definition.source_id]
						)
						matches += 1
			_print("%d match(es)" % matches)
		"mods":
			_print("sources: %s" % ", ".join(Game.load_report.sources))
			for override: Dictionary in registry.overrides():
				_print(
					(
						"  override  %s: %s beat %s"
						% [
							override["id"],
							override["winning_source"],
							override["overridden_source"]
						]
					)
				)
			for source_id: String in Game.load_report.disabled_sources.keys():
				_print(
					"  DISABLED  %s: %s" % [source_id, Game.load_report.disabled_sources[source_id]]
				)
		"events":
			for event_name: String in EventCatalog.names():
				var kind: int = EventCatalog.kind_of(StringName(event_name))
				_print("  %-34s %s" % [event_name, ["notification", "query", "cancellable"][kind]])
		"trace":
			_set_tracing(argument)
		"reload":
			# Hot reload: change a definition on disk and see it without a restart, which
			# is the difference between iterating and rebooting.
			var report: ContentLoader.LoadReport = Game.boot(Game.rng.session_seed())
			_print(report.summary())
		_:
			_print("unknown command '%s'. Type `help`." % command)


func _list(argument: String) -> void:
	var parts: PackedStringArray = argument.split(" ", false)
	if parts.is_empty():
		_print("usage: list <type> [tag]")
		return
	var type_name := StringName(parts[0])
	var definitions: Array = (
		registry.by_tags(type_name, PackedStringArray([parts[1]]))
		if parts.size() > 1
		else registry.by_type(type_name)
	)
	for definition: ContentDefinition in definitions:
		_print("  %s" % definition.id)
	_print("%d definition(s)" % definitions.size())


func _set_tracing(argument: String) -> void:
	match argument:
		"", "on":
			_tracing = true
			_trace_filter = ""
		"off":
			_tracing = false
		_:
			_tracing = true
			_trace_filter = argument
	bus.set_tracing(_tracing)
	_print(
		(
			"tracing %s%s"
			% ["on" if _tracing else "off", (" for '%s'" % _trace_filter) if _trace_filter else ""]
		)
	)


func _on_traced(event_name: StringName, payload: Dictionary, detail: Dictionary) -> void:
	if not _tracing:
		return
	if not _trace_filter.is_empty() and not String(event_name).contains(_trace_filter):
		return
	_print("[color=#9aa0a6]%s %s %s[/color]" % [event_name, payload, detail])


func _print(text: String) -> void:
	_output.append_text(text + "\n")
	if _output.get_line_count() > HISTORY_LINES:
		_output.text = _output.text.substr(_output.text.find("\n") + 1)
