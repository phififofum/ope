class_name NetSession
extends RefCounted

## Host-authoritative session: who is connected, what they are allowed to see, and what
## happens when they join or leave mid-shift.
##
## The rule that shapes this file: [b]ground truth for whether an artifact is forged
## never leaves the host.[/b] A client is sent the fields its currently-held tool
## reveals, and nothing else. The whole game is built on not knowing, so this is a
## security property rather than a balance one -- see SECURITY.md.

const CHANNEL_STATE: StringName = &"state"
const CHANNEL_ENCOUNTER: StringName = &"encounter"
const CHANNEL_VERDICT: StringName = &"verdict"
const CHANNEL_JOIN: StringName = &"join"

## Fields of an encounter that are safe to send. Everything else stays on the host.
const CLIENT_VISIBLE_ENCOUNTER_KEYS: PackedStringArray = [
	"id", "person_name", "tags", "value", "waiting_ticks", "readable_fields", "tell"
]


class RemotePlayer:
	extends RefCounted
	var peer_id: int
	var display_name: String
	var slot_index: int = -1
	var held_tools: PackedStringArray = []
	var connected_tick: int = 0


var transport: LoopbackTransport
var shop: Shop
var is_host: bool = false
var local_peer_id: int = 1

var players: Dictionary = {}  ## peer id -> RemotePlayer
var mirror: Dictionary = {}  ## clients only: the last state the host sent
var encounter_views: Dictionary = {}  ## clients only: encounter id -> redacted view
var rejections: Dictionary = {}  ## peer id -> why the join was refused

var _mod_manifest: Dictionary = {}


func _init(p_transport: LoopbackTransport, p_shop: Shop = null) -> void:
	transport = p_transport
	shop = p_shop


## Starts hosting. [param mod_manifest] is mod id -> version, and it is what joining
## clients are compared against.
func start_host(mod_manifest: Dictionary) -> void:
	is_host = true
	local_peer_id = 1
	_mod_manifest = mod_manifest.duplicate()
	transport.host()
	var host_player := RemotePlayer.new()
	host_player.peer_id = 1
	host_player.display_name = "host"
	host_player.slot_index = 0
	players[1] = host_player


## A client asks to join with its own mod set.
##
## Gameplay-affecting mismatches block; cosmetic-only mismatches warn and continue. Mod
## definitions are never transmitted -- a mismatch is reported, never resolved by
## downloading somebody's code.
func request_join(
	peer_id: int, client_mods: Dictionary, cosmetic_ids: PackedStringArray
) -> Dictionary:
	var missing: Array[String] = []
	var different: Array[String] = []
	var cosmetic_only: Array[String] = []

	for mod_id: String in _mod_manifest.keys():
		if not client_mods.has(mod_id):
			(cosmetic_only if cosmetic_ids.has(mod_id) else missing).append(mod_id)
		elif str(client_mods[mod_id]) != str(_mod_manifest[mod_id]):
			(cosmetic_only if cosmetic_ids.has(mod_id) else different).append(mod_id)
	for mod_id: String in client_mods.keys():
		if not _mod_manifest.has(mod_id):
			(cosmetic_only if cosmetic_ids.has(mod_id) else different).append(mod_id)

	var result: Dictionary = {
		"accepted": missing.is_empty() and different.is_empty(),
		"missing": missing,
		"version_mismatch": different,
		"cosmetic_only": cosmetic_only,
	}
	if not result["accepted"]:
		rejections[peer_id] = result
		transport.send(1, peer_id, CHANNEL_JOIN, result)
		return result

	var player := RemotePlayer.new()
	player.peer_id = peer_id
	player.display_name = "player_%d" % peer_id
	player.slot_index = _next_free_slot()
	player.connected_tick = shop.clock.current_tick() if shop != null else 0
	players[peer_id] = player
	transport.send(1, peer_id, CHANNEL_JOIN, result)
	# Drop-in gets the whole picture immediately: a joining player should not have to
	# wait a tick to see the room.
	broadcast_state()
	return result


## Someone left. Anything they were carrying goes to the floor and their tasks are
## reassigned; shop state must survive a disconnect untouched.
func drop(peer_id: int) -> void:
	players.erase(peer_id)
	transport.disconnect_client(peer_id)
	if shop != null:
		for slot: Shop.PlayerSlot in shop.players:
			if slot.index == peer_id - 1:
				slot.task = Shop.Task.IDLE
				slot.busy_until = shop.clock.current_tick()


## Host: send the authoritative view of the shop. Economy, time and progression are host
## only and broadcast; nothing here is derived on a client.
func broadcast_state() -> void:
	if not is_host or shop == null:
		return
	transport.send(1, 0, CHANNEL_STATE, host_state())


func host_state() -> Dictionary:
	var slots: Array = []
	for slot: Shop.PlayerSlot in shop.players:
		slots.append({"index": slot.index, "task": slot.task, "busy_until": slot.busy_until})
	return {
		"tick": shop.clock.current_tick(),
		"day": shop.day,
		"shift": Shop.SHIFTS[shop.shift_index],
		"money": shop.economy.money,
		"reputation": shop.economy.reputation,
		"queue": shop.waiting_encounters.size(),
		"orders": shop.kitchen.pending_orders().size(),
		"awaiting_check": shop.library.awaiting_check.size(),
		"cleanliness": shop.maintenance.cleanliness,
		"served": shop.served_today,
		"slots": slots,
	}


## Host: send one client what it can see of an encounter, given the tools in its hands.
##
## This is the redaction that the entire design rests on. The applied forgery vectors,
## the person's true intent and any field the client's tools do not reveal are simply
## absent from the payload -- not obfuscated, not flagged: absent.
func send_encounter_view(peer_id: int, encounter: Encounter) -> Dictionary:
	var player: RemotePlayer = players.get(peer_id, null)
	var tools: PackedStringArray = player.held_tools if player != null else PackedStringArray()
	var view: Dictionary = redact_encounter(encounter, tools)
	transport.send(1, peer_id, CHANNEL_ENCOUNTER, view)
	return view


func redact_encounter(encounter: Encounter, held_tools: PackedStringArray) -> Dictionary:
	var artifact: Artifact = encounter.primary_artifact()
	var readable: Dictionary = {}
	if artifact != null and shop != null:
		var document_type: ContentDefinition = shop.registry.get_definition(
			artifact.document_type_id
		)
		if document_type != null:
			for key: String in artifact.readable_fields(document_type, held_tools):
				readable[key] = artifact.field(key)
			for feature_id: String in artifact.checkable_features(document_type, held_tools):
				readable["feature:" + feature_id] = artifact.has_feature(feature_id)
	return {
		"id": encounter.id,
		"person_name": encounter.person.display_name,
		"tags": encounter.transaction_tags,
		"value": encounter.value,
		"waiting_ticks": encounter.opened_tick,
		"readable_fields": readable,
		"tell": encounter.person.tell(),
	}


## Client: a verdict is a request, not a decision. The host resolves it, because a client
## that could decide outcomes could decide them in its own favour.
func request_verdict(encounter_id: int, verdict: int, tools_used: PackedStringArray) -> void:
	transport.send(
		local_peer_id,
		1,
		CHANNEL_VERDICT,
		{"encounter": encounter_id, "verdict": verdict, "tools": tools_used}
	)


## Host: apply whatever clients asked for this tick.
func process_host_inbox() -> Array[Dictionary]:
	var applied: Array[Dictionary] = []
	for envelope: LoopbackTransport.Envelope in transport.receive(1):
		if envelope.channel != CHANNEL_VERDICT or shop == null:
			continue
		var payload: Dictionary = envelope.payload
		var encounter: Encounter = _find_encounter(int(payload.get("encounter", -1)))
		if encounter == null:
			continue
		var slot: Shop.PlayerSlot = _slot_for(envelope.from_peer)
		var tools := PackedStringArray()
		for tool_id: String in payload.get("tools", []):
			tools.append(str(tool_id))
		shop.waiting_encounters.erase(encounter)
		shop.waiting_encounters.push_front(encounter)
		applied.append(
			shop.serve_counter(
				slot, int(payload.get("verdict", 0)), tools, shop.clock.current_tick()
			)
		)
	return applied


## Client: take delivery of whatever the host sent.
func process_client_inbox() -> void:
	for envelope: LoopbackTransport.Envelope in transport.receive(local_peer_id):
		match envelope.channel:
			CHANNEL_STATE:
				mirror = envelope.payload
			CHANNEL_ENCOUNTER:
				encounter_views[int(envelope.payload.get("id", -1))] = envelope.payload
			CHANNEL_JOIN:
				if not bool(envelope.payload.get("accepted", false)):
					rejections[local_peer_id] = envelope.payload


func _find_encounter(encounter_id: int) -> Encounter:
	for encounter: Encounter in shop.waiting_encounters:
		if encounter.id == encounter_id:
			return encounter
	return null


func _slot_for(peer_id: int) -> Shop.PlayerSlot:
	var player: RemotePlayer = players.get(peer_id, null)
	var index: int = player.slot_index if player != null else 0
	if shop == null or shop.players.is_empty():
		return null
	return shop.players[clampi(index, 0, shop.players.size() - 1)]


func _next_free_slot() -> int:
	var taken: Array[int] = []
	for player: RemotePlayer in players.values():
		taken.append(player.slot_index)
	for index: int in range(5):
		if not taken.has(index):
			return index
	return 0
