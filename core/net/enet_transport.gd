class_name EnetTransport
extends NetTransport

## ENet transport: direct IP and LAN, host-authoritative, up to five players.
##
## Deliberately boring. A small interior with five players is not a networking-hard
## problem, and the architecture keeps it that way on purpose.

const DEFAULT_PORT: int = 27015
const MAX_PLAYERS: int = 5

var _peer: ENetMultiplayerPeer
var _multiplayer: MultiplayerAPI
var _peers: Array[int] = []


func _init(multiplayer_api: MultiplayerAPI = null) -> void:
	_multiplayer = multiplayer_api


func host(port: int = DEFAULT_PORT, max_players: int = MAX_PLAYERS) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_server(port, clampi(max_players, 1, MAX_PLAYERS) - 1)
	if error != OK:
		connection_failed.emit("could not open port %d" % port)
		return error
	role = Role.HOST
	_attach()
	_peers = [1]
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_client(address, port)
	if error != OK:
		connection_failed.emit("could not reach %s:%d" % [address, port])
		return error
	role = Role.CLIENT
	_attach()
	return OK


func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_peers.clear()
	super.close()


func peers() -> PackedInt32Array:
	var sorted: Array[int] = _peers.duplicate()
	sorted.sort()
	return PackedInt32Array(sorted)


func local_peer_id() -> int:
	if _multiplayer != null and _multiplayer.has_multiplayer_peer():
		return _multiplayer.get_unique_id()
	return 1


func _attach() -> void:
	if _multiplayer == null:
		return
	_multiplayer.multiplayer_peer = _peer
	if not _multiplayer.peer_connected.is_connected(_on_peer_connected):
		_multiplayer.peer_connected.connect(_on_peer_connected)
		_multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_multiplayer.connected_to_server.connect(_on_connected)
		_multiplayer.connection_failed.connect(_on_failed)


func _on_peer_connected(peer_id: int) -> void:
	if not _peers.has(peer_id):
		_peers.append(peer_id)
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_peers.erase(peer_id)
	peer_disconnected.emit(peer_id)


func _on_connected() -> void:
	_peers.append(local_peer_id())
	connection_succeeded.emit()


func _on_failed() -> void:
	role = Role.OFFLINE
	connection_failed.emit("handshake failed")
