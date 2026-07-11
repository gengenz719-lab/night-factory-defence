class_name NetworkTestDriver
extends Node

var coordinator: RunCoordinator
var elapsed: float = 0.0
var phase: int = 0
var active: bool = false
var replicator: NetStateReplicator
var saw_remote_movement: bool = false
var saw_enemy_snapshot: bool = false
var saw_vehicle_damage: bool = false
var saw_vehicle_repair: bool = false
var saw_wave_two: bool = false
var saw_victory: bool = false
var _initial_remote_position: Vector2 = Vector2.ZERO
var _lowest_front_hp: float = INF


func setup(run: RunCoordinator) -> void:
	coordinator = run
	replicator = coordinator.net_state_replicator
	active = OS.get_cmdline_user_args().has("--network-test-host") or OS.get_cmdline_user_args().has("--network-test-client")
	if not active:
		return
	replicator.remote_player_snapshot_received.connect(_on_remote_player_snapshot)
	replicator.enemy_snapshot_received.connect(func() -> void: saw_enemy_snapshot = true)
	replicator.vehicle_snapshot_received.connect(_on_vehicle_snapshot)
	replicator.run_state_received.connect(_on_run_state)
	for peer_key: Variant in coordinator.players_by_peer:
		if int(peer_key) != NetworkSession.local_peer_id():
			_initial_remote_position = (coordinator.players_by_peer[peer_key] as CrewPlayer).position


func _process(delta: float) -> void:
	if not active or not NetworkSession.is_host_authority():
		return
	elapsed += delta
	match phase:
		0:
			if elapsed >= 0.25:
				coordinator.stage_director.begin_combat()
				var enemy: EnemyUnit = coordinator.enemy_director.spawn_enemy()
				if enemy != null:
					enemy.position = Vector2(430.0, 675.0)
				coordinator.vehicle_state.take_attack(&"front", 60.0)
				phase = 1
		1:
			if elapsed >= 3.0:
				coordinator.stage_director.finish_wave()
				phase = 2
		2:
			if elapsed >= 3.35 and not coordinator.active_relic_choices.is_empty():
				coordinator.select_relic(0)
				coordinator.stage_director.begin_combat()
				phase = 3
		3:
			if elapsed >= 5.5:
				coordinator.stage_director.finish_wave()
				phase = 4
		4:
			if elapsed >= 6.2:
				_request_network_test_report()
				phase = 5


func _on_remote_player_snapshot(_peer_id: int, position_value: Vector2) -> void:
	if position_value.distance_to(_initial_remote_position) > 4.0:
		saw_remote_movement = true


func _on_vehicle_snapshot(front_hp: float) -> void:
	if front_hp < float(coordinator.vehicle_state.max_section_hp[&"front"]):
		saw_vehicle_damage = true
		_lowest_front_hp = minf(_lowest_front_hp, front_hp)
	if saw_vehicle_damage and front_hp > _lowest_front_hp + 1.0:
		saw_vehicle_repair = true


func _on_run_state(state: int, wave_index: int) -> void:
	saw_wave_two = saw_wave_two or wave_index >= 1
	saw_victory = saw_victory or state == StageDirector.RunState.VICTORY


func _request_network_test_report() -> void:
	var host_player := coordinator.players_by_peer.get(NetworkSession.HOST_PEER_ID) as CrewPlayer
	var client_player: CrewPlayer = _find_client_player()
	var client_position: Vector2 = client_player.position if client_player != null else Vector2.ZERO
	var state_hash: String = _state_hash(
		coordinator.stage_director.state, coordinator.stage_director.wave_index,
		coordinator.vehicle_state.hull, float(coordinator.vehicle_state.section_hp[&"front"]),
		coordinator.reward_system.kills, host_player.position, client_position
	)
	_receive_final_test_state.rpc(
		state_hash, coordinator.stage_director.state, coordinator.stage_director.wave_index,
		coordinator.vehicle_state.hull, float(coordinator.vehicle_state.section_hp[&"front"]),
		coordinator.reward_system.kills, host_player.position, client_position
	)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_final_test_state(host_hash: String, state: int, wave_index: int, hull: float, front: float, kills: int, host_position: Vector2, client_position: Vector2) -> void:
	if NetworkSession.is_host_authority():
		return
	coordinator.apply_stage_snapshot(state, wave_index, 0.0)
	coordinator.vehicle_state.hull = hull
	coordinator.vehicle_state.section_hp[&"front"] = front
	coordinator.reward_system.kills = kills
	(coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer).position = host_position
	(coordinator.players_by_peer[NetworkSession.local_peer_id()] as CrewPlayer).position = client_position
	var client_hash: String = _state_hash(state, wave_index, hull, front, kills, host_position, client_position)
	var average_correction: float = replicator.correction_sum / maxf(1.0, float(replicator.correction_count))
	_submit_network_test_report.rpc_id(
		NetworkSession.HOST_PEER_ID,
		saw_remote_movement, saw_enemy_snapshot, saw_vehicle_damage, saw_vehicle_repair,
		saw_wave_two, saw_victory, replicator.confirmed_shots > 0, host_hash == client_hash,
		replicator.max_correction, average_correction
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_network_test_report(
	remote_moved: bool, enemy_synced: bool, vehicle_damaged: bool, vehicle_repaired: bool,
	wave_two: bool, victory: bool, shots_synced: bool, hash_matched: bool,
	client_max_correction: float, client_average_correction: float
) -> void:
	if not NetworkSession.is_host_authority():
		return
	var passed: bool = (
		remote_moved and enemy_synced and vehicle_damaged and vehicle_repaired and
		wave_two and victory and shots_synced and hash_matched and
		replicator.remote_inputs_received > 0 and replicator.confirmed_shots > 0
	)
	print("NETWORK_TEST_%s inputs=%d shots=%d kills=%d hash=%s max_correction=%.3f avg_correction=%.3f" % [
		"PASS" if passed else "FAIL", replicator.remote_inputs_received, replicator.confirmed_shots,
		coordinator.reward_system.kills, hash_matched, client_max_correction, client_average_correction,
	])
	_finish_network_test.rpc(passed)
	call_deferred(&"_quit_host_after_flush", passed)


@rpc("authority", "call_remote", "reliable", 0)
func _finish_network_test(passed: bool) -> void:
	print("NETWORK_CLIENT_%s" % ("PASS" if passed else "FAIL"))
	get_tree().quit(0 if passed else 1)


func _quit_host_after_flush(passed: bool) -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if passed else 1)


func _find_client_player() -> CrewPlayer:
	for peer_key: Variant in coordinator.players_by_peer:
		if int(peer_key) != NetworkSession.HOST_PEER_ID:
			return coordinator.players_by_peer[peer_key] as CrewPlayer
	return null


func _state_hash(state: int, wave_index: int, hull: float, front: float, kills: int, host_position: Vector2, client_position: Vector2) -> String:
	return str(hash("%d|%d|%.2f|%.2f|%d|%.2f|%.2f|%.2f|%.2f" % [
		state, wave_index, hull, front, kills,
		host_position.x, host_position.y, client_position.x, client_position.y,
	]))
