extends GdUnitTestSuite

## Phase 4: five peers run a shift together, and the thing the whole design rests on --
## that a client cannot learn whether an artifact is forged -- is asserted against what
## actually crossed the wire.

var registry: ContentRegistry


func before() -> void:
	registry = ContentRegistry.new()
	ContentLoader.new(registry).load_all("res://content", "res://tests/no_mods")


func _session(seed_value: int, players: int = 5) -> Array:
	var transport := LoopbackTransport.new()
	var shop := Shop.new(
		registry,
		EventBus.new(),
		SeededRng.new(seed_value),
		Director.Profile.preset("standard"),
		players
	)
	shop.open_for_business(600.0)
	var host := NetSession.new(transport, shop)
	host.start_host({"base": "0.1.0"})
	return [transport, shop, host]


func _join(
	transport: LoopbackTransport, host: NetSession, mods: Dictionary = {"base": "0.1.0"}
) -> Array:
	var peer_id: int = transport.connect_client()
	var result: Dictionary = host.request_join(peer_id, mods, PackedStringArray())
	var client := NetSession.new(transport)
	client.local_peer_id = peer_id
	client.process_client_inbox()
	return [peer_id, client, result]


func test_five_peers_run_a_day_and_converge() -> void:
	var parts: Array = _session(101)
	var transport: LoopbackTransport = parts[0]
	var shop: Shop = parts[1]
	var host: NetSession = parts[2]

	var clients: Array[NetSession] = []
	for _index: int in range(4):
		clients.append(_join(transport, host)[1])

	shop.start_day(1)
	for tick_index: int in range(Shop.DAY_TICKS):
		shop.tick()
		var now: int = shop.clock.current_tick()
		for slot: Shop.PlayerSlot in shop.free_players(now):
			if not shop.waiting_encounters.is_empty():
				shop.serve_counter(
					slot, Encounter.Verdict.APPROVE, PackedStringArray(["base:naked_eye"]), now
				)
			elif not shop.kitchen.pending_orders().is_empty():
				shop.cook_next(slot, now)
		if tick_index % 200 == 0:
			host.broadcast_state()
			for client: NetSession in clients:
				client.process_client_inbox()
	host.broadcast_state()
	for client: NetSession in clients:
		client.process_client_inbox()

	var truth: Dictionary = host.host_state()
	for client: NetSession in clients:
		assert_int(int(client.mirror["tick"])).is_equal(int(truth["tick"]))
		assert_float(float(client.mirror["money"])).is_equal_approx(float(truth["money"]), 0.001)
		assert_int(int(client.mirror["served"])).is_equal(int(truth["served"]))
		assert_int(int(client.mirror["queue"])).is_equal(int(truth["queue"]))


func test_artifact_truth_never_leaves_the_host() -> void:
	# The security property, checked against the wire rather than against intent.
	var parts: Array = _session(202)
	var transport: LoopbackTransport = parts[0]
	var shop: Shop = parts[1]
	var host: NetSession = parts[2]
	var client_parts: Array = _join(transport, host)
	var peer_id: int = client_parts[0]
	var client: NetSession = client_parts[1]

	(host.players[peer_id] as NetSession.RemotePlayer).held_tools = PackedStringArray(
		["base:naked_eye", "base:uv_torch"]
	)
	shop.start_day(1)
	shop.verification.set_today(1)

	# A forged encounter for every document type, so the redaction is exercised on all of
	# them rather than on whichever one the director happened to schedule.
	var factory := PersonFactory.new(SeededRng.new(7), 1)
	var forged: int = 0
	for document_type: ContentDefinition in registry.by_type(&"document_type"):
		var encounter: Encounter = shop.verification.create(
			document_type.id,
			factory.create_stranger(25, 45),
			PackedStringArray(["id_required", "trade_in", "authentication"]),
			true,
			4,
			120.0,
			shop.owned_tools
		)
		if encounter == null:
			continue
		if encounter.is_forged():
			forged += 1
		host.send_encounter_view(peer_id, encounter)

	for _tick_index: int in range(2000):
		shop.tick()
		host.broadcast_state()
	client.process_client_inbox()

	(
		assert_int(forged)
		. override_failure_message(
			"no forged encounter occurred, so the redaction was never exercised"
		)
		. is_greater(0)
	)

	var wire: String = ""
	for envelope: LoopbackTransport.Envelope in transport.wire_log():
		wire += JSON.stringify(envelope.payload)
	for secret: String in [
		"applied_vectors", "is_attempting_fraud", "forged_fields", "was_forged", "knows_it_is_fake"
	]:
		(
			assert_str(wire)
			. override_failure_message(
				"'%s' crossed the wire; a modified client could read the answer" % secret
			)
			. not_contains(secret)
		)
	for vector: ContentDefinition in registry.by_type(&"forgery_vector"):
		assert_str(wire).not_contains(String(vector.id))


func test_a_client_only_sees_fields_its_tools_reveal() -> void:
	var parts: Array = _session(303)
	var shop: Shop = parts[1]
	var host: NetSession = parts[2]

	var person: Person = PersonFactory.new(SeededRng.new(1), 1).create_stranger(30, 40)
	shop.verification.set_today(1)
	var encounter: Encounter = shop.verification.create(
		&"base:state_id_northvale", person, PackedStringArray(["id_required"]), false, 0
	)

	var naked_eye: Dictionary = host.redact_encounter(
		encounter, PackedStringArray(["base:naked_eye"])
	)
	assert_bool((naked_eye["readable_fields"] as Dictionary).has("dob")).is_true()
	(
		assert_bool((naked_eye["readable_fields"] as Dictionary).has("barcode"))
		. override_failure_message("the barcode is readable without the scanner")
		. is_false()
	)

	var with_scanner: Dictionary = host.redact_encounter(
		encounter, PackedStringArray(["base:naked_eye", "base:barcode_scanner"])
	)
	assert_bool((with_scanner["readable_fields"] as Dictionary).has("barcode")).is_true()

	var with_torch: Dictionary = host.redact_encounter(
		encounter, PackedStringArray(["base:naked_eye", "base:uv_torch"])
	)
	assert_bool((with_torch["readable_fields"] as Dictionary).has("feature:uv_seal")).is_true()
	assert_bool((naked_eye["readable_fields"] as Dictionary).has("feature:uv_seal")).is_false()


func test_a_verdict_is_a_request_the_host_resolves() -> void:
	var parts: Array = _session(404)
	var transport: LoopbackTransport = parts[0]
	var shop: Shop = parts[1]
	var host: NetSession = parts[2]
	var client_parts: Array = _join(transport, host)
	var client: NetSession = client_parts[1]

	shop.start_day(1)
	while shop.waiting_encounters.is_empty():
		shop.tick()
	var encounter: Encounter = shop.waiting_encounters[0]

	client.request_verdict(
		encounter.id, Encounter.Verdict.DECLINE, PackedStringArray(["base:naked_eye"])
	)
	var applied: Array[Dictionary] = host.process_host_inbox()

	assert_int(applied.size()).is_equal(1)
	assert_str(str(applied[0]["verdict"])).is_equal("decline")
	assert_int(shop.waiting_encounters.size()).is_equal(0)


func test_joining_mid_shift_gets_the_whole_picture() -> void:
	var parts: Array = _session(505)
	var transport: LoopbackTransport = parts[0]
	var shop: Shop = parts[1]
	var host: NetSession = parts[2]

	shop.start_day(1)
	for _tick_index: int in range(4000):
		shop.tick()

	var client_parts: Array = _join(transport, host)
	var client: NetSession = client_parts[1]
	client.process_client_inbox()

	(
		assert_bool(client.mirror.is_empty())
		. override_failure_message("a joining player waited a tick to see the room")
		. is_false()
	)
	assert_int(int(client.mirror["tick"])).is_equal(shop.clock.current_tick())
	assert_int(int(client.mirror["day"])).is_equal(1)


func test_a_disconnect_never_loses_shop_state() -> void:
	var parts: Array = _session(606)
	var transport: LoopbackTransport = parts[0]
	var shop: Shop = parts[1]
	var host: NetSession = parts[2]
	var client_parts: Array = _join(transport, host)
	var peer_id: int = client_parts[0]

	shop.start_day(1)
	for _tick_index: int in range(3000):
		shop.tick()
	var before: Dictionary = host.host_state()

	host.drop(peer_id)

	var after: Dictionary = host.host_state()
	assert_float(float(after["money"])).is_equal_approx(float(before["money"]), 0.0001)
	assert_int(int(after["queue"])).is_equal(int(before["queue"]))
	assert_int(int(after["served"])).is_equal(int(before["served"]))
	assert_bool(host.players.has(peer_id)).is_false()


func test_dropping_mid_encounter_leaves_the_encounter_intact() -> void:
	var parts: Array = _session(707)
	var transport: LoopbackTransport = parts[0]
	var shop: Shop = parts[1]
	var host: NetSession = parts[2]
	var client_parts: Array = _join(transport, host)
	var peer_id: int = client_parts[0]

	shop.start_day(1)
	while shop.waiting_encounters.is_empty():
		shop.tick()
	var queued: int = shop.waiting_encounters.size()
	host.send_encounter_view(peer_id, shop.waiting_encounters[0])
	host.drop(peer_id)

	assert_int(shop.waiting_encounters.size()).is_equal(queued)
	# The customer is still there and still servable by whoever is left.
	var slot: Shop.PlayerSlot = shop.players[0]
	var result: Dictionary = shop.serve_counter(
		slot,
		Encounter.Verdict.APPROVE,
		PackedStringArray(["base:naked_eye"]),
		shop.clock.current_tick()
	)
	assert_bool(result.is_empty()).is_false()


func test_a_gameplay_mod_mismatch_blocks_the_join() -> void:
	var parts: Array = _session(808)
	var transport: LoopbackTransport = parts[0]
	var host: NetSession = parts[2]
	host.start_host({"base": "0.1.0", "veto_mod": "1.0.0"})

	var result: Dictionary = _join(transport, host, {"base": "0.1.0"})[2]
	assert_bool(bool(result["accepted"])).is_false()
	assert_array(result["missing"]).contains(["veto_mod"])

	var wrong_version: Dictionary = _join(transport, host, {"base": "0.1.0", "veto_mod": "2.0.0"})[2]
	assert_bool(bool(wrong_version["accepted"])).is_false()
	assert_array(wrong_version["version_mismatch"]).contains(["veto_mod"])


func test_a_cosmetic_mod_mismatch_only_warns() -> void:
	var parts: Array = _session(909)
	var transport: LoopbackTransport = parts[0]
	var host: NetSession = parts[2]
	host.start_host({"base": "0.1.0", "cosmetic_mod": "1.1.0"})

	var peer_id: int = transport.connect_client()
	var result: Dictionary = host.request_join(
		peer_id, {"base": "0.1.0"}, PackedStringArray(["cosmetic_mod"])
	)
	assert_bool(bool(result["accepted"])).is_true()
	assert_array(result["cosmetic_only"]).contains(["cosmetic_mod"])


func test_mod_definitions_are_never_transmitted() -> void:
	var parts: Array = _session(1010)
	var transport: LoopbackTransport = parts[0]
	var host: NetSession = parts[2]
	host.start_host({"base": "0.1.0", "veto_mod": "1.0.0"})
	_join(transport, host, {"base": "0.1.0"})

	# A mismatch is reported, never resolved by shipping somebody's code across.
	var wire: String = ""
	for envelope: LoopbackTransport.Envelope in transport.wire_log():
		wire += JSON.stringify(envelope.payload)
	assert_str(wire).not_contains("_enter_mod")
	assert_str(wire).not_contains("definitions/")
	assert_str(wire).not_contains(".gd")
