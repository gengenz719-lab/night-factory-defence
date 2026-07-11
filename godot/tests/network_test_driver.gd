class_name NetworkTestDriver
extends Node

var coordinator: RunCoordinator
var elapsed: float = 0.0
var phase: int = 0
var active: bool = false
var replicator: PlayerNetReplicator
var state_replicator: NetStateReplicator
var saw_remote_movement: bool = false
var saw_enemy_snapshot: bool = false
var saw_vehicle_damage: bool = false
var saw_vehicle_repair: bool = false
var saw_wave_two: bool = false
var saw_victory: bool = false
var _initial_remote_position: Vector2 = Vector2.ZERO
var _lowest_front_hp: float = INF
var saw_dodge_state: bool = false
var saw_downed_state: bool = false
var saw_revived_state: bool = false
var saw_departed_state: bool = false
var saw_returned_state: bool = false
var dodge_authority_pass: bool = false
var down_duration_pass: bool = false
var revive_authority_pass: bool = false
var return_authority_pass: bool = false
var character_selection_pass: bool = false
var ability_authority_pass: bool = false
var saw_ability_state: bool = false
var _supplies_before_drone: float = 0.0


func setup(run: RunCoordinator) -> void:
	coordinator = run
	replicator = coordinator.player_net_replicator
	state_replicator = coordinator.net_state_replicator
	active = OS.get_cmdline_user_args().has("--network-test-host") or OS.get_cmdline_user_args().has("--network-test-client")
	if not active:
		return
	replicator.remote_player_snapshot_received.connect(_on_remote_player_snapshot)
	state_replicator.enemy_snapshot_received.connect(func() -> void: saw_enemy_snapshot = true)
	state_replicator.vehicle_snapshot_received.connect(_on_vehicle_snapshot)
	state_replicator.run_state_received.connect(_on_run_state)
	replicator.player_survival_snapshot_received.connect(_on_player_survival_snapshot)
	replicator.player_ability_snapshot_received.connect(_on_player_ability_snapshot)
	var host_player := coordinator.players_by_peer.get(NetworkSession.HOST_PEER_ID) as CrewPlayer
	var client_player: CrewPlayer = _find_client_player()
	character_selection_pass = host_player != null and client_player != null and host_player.definition.id == &"character_gunner" and client_player.definition.id == &"character_engineer"
	for peer_key: Variant in coordinator.players_by_peer:
		if int(peer_key) != NetworkSession.local_peer_id():
			_initial_remote_position = (coordinator.players_by_peer[peer_key] as CrewPlayer).position


func _process(delta: float) -> void:
	if not active or not NetworkSession.is_host_authority():
		return
	elapsed += delta
	if elapsed >= 12.0 and phase < 9:
		var host_player := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
		var client_player: CrewPlayer = _find_client_player()
		print("NETWORK_TEST_TIMEOUT phase=%d revive=%.2f host_down=%s client_down=%s client_departed=%s host_pos=%s client_pos=%s distance=%.1f range=%.1f intents=%d inputs=%d" % [
			phase, host_player.survival.revive_progress, host_player.survival.is_downed,
			client_player.survival.is_downed, client_player.survival.is_departed,
			host_player.position, client_player.position,
			host_player.position.distance_to(client_player.position),
			client_player.definition.revive_interaction_range_px,
			coordinator.revive_controller.revive_target_by_peer.size(),
			replicator.remote_inputs_received,
		])
		get_tree().quit(1)
		return
	match phase:
		0:
			if elapsed >= 0.25:
				coordinator.stage_director.begin_combat()
				var enemy: EnemyUnit = coordinator.enemy_director.spawn_enemy()
				if enemy != null:
					enemy.position = Vector2(430.0, 675.0)
				coordinator.vehicle_state.take_attack(&"front", 60.0)
				_supplies_before_drone = coordinator.vehicle_state.supplies
				phase = 1
		1:
			if elapsed >= 0.65:
				var client_player: CrewPlayer = _find_client_player()
				var hp_before: float = client_player.survival.hp
				var host_player := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
				ability_authority_pass = (
					replicator.remote_ability_intents_received > 0 and replicator.abilities_confirmed >= 2 and
					host_player.ability_active_time > 0.0 and client_player.ability_active_time > 0.0 and
					host_player.effective_fire_interval() < 1.0 / host_player.weapon_definition.shots_per_second and
					float(coordinator.vehicle_state.section_hp[&"front"]) > float(coordinator.vehicle_state.max_section_hp[&"front"]) - 60.0 and
					is_equal_approx(coordinator.vehicle_state.supplies, _supplies_before_drone)
				)
				client_player.take_damage(10.0)
				dodge_authority_pass = (
					replicator.remote_dodge_intents_received > 0 and
					replicator.dodges_confirmed >= 2 and
					is_equal_approx(client_player.survival.hp, hp_before)
				)
				phase = 2
		2:
			if elapsed >= 1.0:
				var host_player := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
				var client_player: CrewPlayer = _find_client_player()
				client_player.position = host_player.position + Vector2(50.0, 0.0)
				host_player.take_damage(9999.0)
				down_duration_pass = (
					host_player.survival.is_downed and
					is_equal_approx(host_player.survival.downed_time, host_player.definition.downed_grace_seconds)
				)
				phase = 3
		3:
			var host_player := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
			var client_player: CrewPlayer = _find_client_player()
			var revive_range: float = client_player.definition.revive_interaction_range_px
			if host_player.position.distance_to(client_player.position) > revive_range * 0.8:
				client_player.position = host_player.position + Vector2(revive_range * 0.5, 0.0)
			if not host_player.survival.is_downed:
				revive_authority_pass = (
					coordinator.revive_controller.revives_confirmed > 0 and
					is_equal_approx(host_player.survival.hp, host_player.survival.max_hp * host_player.definition.revive_health_ratio) and
					host_player.survival.invulnerable_time > 0.0
				)
				client_player.survival.invulnerable_time = 0.0
				client_player.take_damage(9999.0)
				down_duration_pass = down_duration_pass and is_equal_approx(client_player.survival.downed_time, client_player.definition.downed_grace_seconds)
				client_player.survival.downed_time = 0.25
				phase = 4
		4:
			var client_player: CrewPlayer = _find_client_player()
			if client_player.survival.is_departed:
				return_authority_pass = absf(client_player.survival.return_time - client_player.definition.return_wait_seconds) <= 0.1
				client_player.survival.return_time = 0.25
				phase = 5
		5:
			var client_player: CrewPlayer = _find_client_player()
			if not client_player.survival.is_departed and not client_player.survival.is_downed:
				return_authority_pass = return_authority_pass and is_equal_approx(
					client_player.survival.hp,
					client_player.survival.max_hp * client_player.definition.return_health_ratio
				)
				phase = 6
		6:
			if elapsed >= 6.0:
				coordinator.stage_director.finish_wave()
				phase = 7
		7:
			if elapsed >= 6.35 and not coordinator.active_relic_choices.is_empty():
				coordinator.select_relic(0)
				coordinator.stage_director.begin_combat()
				phase = 8
		8:
			if elapsed >= 8.5:
				coordinator.stage_director.finish_wave()
				phase = 9
		9:
			if elapsed >= 9.2:
				_request_network_test_report()
				phase = 10


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


func _on_player_survival_snapshot(_peer_id: int, downed: bool, departed: bool, invulnerability: float, dodge_cooldown: float, hp: float) -> void:
	saw_dodge_state = saw_dodge_state or (invulnerability > 0.0 and dodge_cooldown > 0.0)
	if downed:
		saw_downed_state = true
	if saw_downed_state and not downed and not departed and hp > 0.0:
		saw_revived_state = true
	if departed:
		saw_departed_state = true
	if saw_departed_state and not departed and not downed and hp > 0.0:
		saw_returned_state = true


func _on_player_ability_snapshot(_peer_id: int, active_time: float, cooldown: float) -> void:
	saw_ability_state = saw_ability_state or (active_time > 0.0 and cooldown > 0.0)


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
		saw_dodge_state, saw_downed_state, saw_revived_state, saw_departed_state, saw_returned_state,
		saw_ability_state,
		replicator.max_correction, average_correction
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_network_test_report(
	remote_moved: bool, enemy_synced: bool, vehicle_damaged: bool, vehicle_repaired: bool,
	wave_two: bool, victory: bool, shots_synced: bool, hash_matched: bool,
	dodge_synced: bool, downed_synced: bool, revived_synced: bool, departed_synced: bool, returned_synced: bool,
	ability_synced: bool,
	client_max_correction: float, client_average_correction: float
) -> void:
	if not NetworkSession.is_host_authority():
		return
	var passed: bool = (
		remote_moved and enemy_synced and vehicle_damaged and vehicle_repaired and
		wave_two and victory and shots_synced and hash_matched and
		dodge_synced and downed_synced and revived_synced and departed_synced and returned_synced and
		ability_synced and character_selection_pass and ability_authority_pass and
		dodge_authority_pass and down_duration_pass and revive_authority_pass and return_authority_pass and
		replicator.remote_inputs_received > 0 and replicator.confirmed_shots > 0
	)
	print("NETWORK_TEST_%s inputs=%d shots=%d kills=%d characters=%s abilities=%s dodge=%s revive=%s return=%s hash=%s max_correction=%.3f avg_correction=%.3f" % [
		"PASS" if passed else "FAIL", replicator.remote_inputs_received, replicator.confirmed_shots,
		coordinator.reward_system.kills, character_selection_pass, ability_authority_pass, dodge_authority_pass, revive_authority_pass,
		return_authority_pass, hash_matched, client_max_correction, client_average_correction,
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
