class_name LoopbackTransport
extends NetTransport

## An in-process transport: peers exchange the same serialised payloads they would over
## the wire, without a socket.
##
## It exists so the replication rules can be tested exhaustively and deterministically --
## including the one that matters most, that artifact truth never leaves the host. A test
## that inspects real UDP packets would be slower, flakier and no more convincing.


class Envelope:
	extends RefCounted
	var from_peer: int
	var to_peer: int  ## 0 broadcasts
	var channel: StringName
	var payload: Dictionary


var _peers: Array[int] = []
var _inbox: Dictionary = {}  ## peer id -> Array[Envelope]
var _wire_log: Array[Envelope] = []
var _local_id: int = 1
var _next_peer_id: int = 2


func host(_port: int = 0, _max_players: int = 5) -> Error:
	role = Role.HOST
	_local_id = 1
	_register(1)
	return OK


## Adds a client and returns its peer id. In a loopback session both ends live in one
## process, so joining is a function call rather than a handshake.
func connect_client() -> int:
	var peer_id: int = _next_peer_id
	_next_peer_id += 1
	_register(peer_id)
	peer_connected.emit(peer_id)
	return peer_id


func disconnect_client(peer_id: int) -> void:
	_peers.erase(peer_id)
	_inbox.erase(peer_id)
	peer_disconnected.emit(peer_id)


func close() -> void:
	_peers.clear()
	_inbox.clear()
	super.close()


func peers() -> PackedInt32Array:
	var sorted: Array[int] = _peers.duplicate()
	sorted.sort()
	return PackedInt32Array(sorted)


func local_peer_id() -> int:
	return _local_id


func send(from_peer: int, to_peer: int, channel: StringName, payload: Dictionary) -> void:
	var envelope := Envelope.new()
	envelope.from_peer = from_peer
	envelope.to_peer = to_peer
	envelope.channel = channel
	# Serialise through JSON exactly as the wire would: anything that cannot survive that
	# round trip would not survive the network either, and object references certainly
	# do not.
	envelope.payload = JSON.parse_string(JSON.stringify(payload))
	_wire_log.append(envelope)
	for peer_id: int in _peers:
		if peer_id == from_peer:
			continue
		if to_peer == 0 or to_peer == peer_id:
			(_inbox[peer_id] as Array).append(envelope)


func receive(peer_id: int) -> Array:
	var messages: Array = _inbox.get(peer_id, [])
	_inbox[peer_id] = []
	return messages


## Everything that has crossed the wire this session. Tests assert on this: it is the
## only honest way to check that a secret never left the host.
func wire_log() -> Array[Envelope]:
	return _wire_log.duplicate()


func _register(peer_id: int) -> void:
	if not _peers.has(peer_id):
		_peers.append(peer_id)
	_inbox[peer_id] = []
