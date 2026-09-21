class_name NetTransport
extends RefCounted

## The seam between the game and whatever carries its packets.
##
## v1 ships direct IP and LAN over ENet. Steam lobbies and NAT punch-through arrive later
## as another implementation of this interface, with zero changes to game code — which is
## the only reason deferring them is safe.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed(reason: String)
signal connection_succeeded

enum Role { OFFLINE, HOST, CLIENT }

var role: Role = Role.OFFLINE


## Start hosting. Returns OK, or an error the UI can show.
func host(_port: int, _max_players: int) -> Error:
	push_error("NetTransport.host is abstract")
	return ERR_UNCONFIGURED


func join(_address: String, _port: int) -> Error:
	push_error("NetTransport.join is abstract")
	return ERR_UNCONFIGURED


func close() -> void:
	role = Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


func is_online() -> bool:
	return role != Role.OFFLINE


## The peer ids currently connected, host included, sorted — determinism again: role
## assignment must not depend on connection order.
func peers() -> PackedInt32Array:
	return PackedInt32Array()


func local_peer_id() -> int:
	return 1


## A short description for the UI and the telemetry log.
func describe() -> String:
	match role:
		Role.HOST:
			return "hosting"
		Role.CLIENT:
			return "connected"
		_:
			return "offline"
