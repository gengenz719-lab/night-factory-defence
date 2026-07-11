class_name NetStateReplicator
extends Node

signal remote_player_snapshot_received(peer_id: int, position_value: Vector2)
signal enemy_snapshot_received
signal vehicle_snapshot_received(front_hp: float)
signal run_state_received(state: int, wave_index: int)

const INPUT_INTERVAL: float = 1.0 / 30.0
const PLAYER_SNAPSHOT_INTERVAL: float = 1.0 / 20.0
const ENEMY_SNAPSHOT_INTERVAL: float = 1.0 / 12.0
const VEHICLE_SNAPSHOT_INTERVAL: float = 0.5
const WAVE_CLOCK_INTERVAL: float = 1.0

var coordinator: RunCoordinator
var players_by_peer: Dictionary = {}
var local_player: CrewPlayer
var input_sequence: int = 0
var input_accumulator: float = 0.0
var player_snapshot_accumulator: float = 0.0
var enemy_snapshot_accumulator: float = 0.0
var vehicle_snapshot_accumulator: float = 0.0
var wave_clock_accumulator: float = 0.0
var last_processed_input: Dictionary = {}
var input_history: Array[Dictionary] = []
var correction_sum: float = 0.0
var correction_count: int = 0
var max_correction: float = 0.0
var remote_inputs_received: int = 0
var confirmed_shots: int = 0
var initialized: bool = false
var automated_test: bool = false
var test_elapsed: float = 0.0
var remote_sync_ready: bool = false
var jump_intent_frames: int = 0
var drop_intent_frames: int = 0


func setup(run: RunCoordinator, players: Dictionary) -> void:
	coordinator = run
	players_by_peer = players
	local_player = players_by_peer.get(NetworkSession.local_peer_id()) as CrewPlayer
	automated_test = OS.get_cmdline_user_args().has("--network-test-host") or OS.get_cmdline_user_args().has("--network-test-client")
	coordinator.enemy_director.enemy_removed.connect(_on_enemy_removed)
	NetworkSession.session_failed.connect(_on_session_failed)
	initialized = true
	remote_sync_ready = NetworkSession.role == NetworkSession.SessionRole.SOLO
	if NetworkSession.is_host_authority():
		broadcast_run_state()


func _physics_process(delta: float) -> void:
	if not initialized or local_player == null:
		return
	test_elapsed += delta
	if NetworkSession.is_host_authority() and not remote_sync_ready and test_elapsed >= 0.5:
		remote_sync_ready = true
		broadcast_run_state()
	input_accumulator += delta
	if input_accumulator >= INPUT_INTERVAL:
		input_accumulator -= INPUT_INTERVAL
		_capture_local_input()
	if not NetworkSession.is_host_authority() or not remote_sync_ready:
		return
	player_snapshot_accumulator += delta
	enemy_snapshot_accumulator += delta
	vehicle_snapshot_accumulator += delta
	wave_clock_accumulator += delta
	if player_snapshot_accumulator >= PLAYER_SNAPSHOT_INTERVAL:
		player_snapshot_accumulator -= PLAYER_SNAPSHOT_INTERVAL
		_send_player_snapshots()
	if enemy_snapshot_accumulator >= ENEMY_SNAPSHOT_INTERVAL:
		enemy_snapshot_accumulator -= ENEMY_SNAPSHOT_INTERVAL
		_send_enemy_snapshots()
	if vehicle_snapshot_accumulator >= VEHICLE_SNAPSHOT_INTERVAL:
		vehicle_snapshot_accumulator -= VEHICLE_SNAPSHOT_INTERVAL
		_send_vehicle_snapshot()
	if wave_clock_accumulator >= WAVE_CLOCK_INTERVAL:
		wave_clock_accumulator -= WAVE_CLOCK_INTERVAL
		_receive_wave_clock.rpc(coordinator.stage_director.wave_index, coordinator.stage_director.state_time)


func _capture_local_input() -> void:
	input_sequence += 1
	var axis := Vector2(Input.get_axis(&"move_left", &"move_right"), 0.0)
	if Input.is_action_just_pressed(&"jump"):
		jump_intent_frames = 3
	if Input.is_action_just_pressed(&"drop_down"):
		drop_intent_frames = 3
	if jump_intent_frames > 0:
		axis.y = -1.0
		jump_intent_frames -= 1
	elif drop_intent_frames > 0:
		axis.y = 1.0
		drop_intent_frames -= 1
	var aim: Vector2 = local_player.position.direction_to(local_player.get_global_mouse_position())
	var wants_fire: bool = Input.is_action_pressed(&"fire_primary")
	var wants_repair: bool = Input.is_action_pressed(&"interact")
	if automated_test:
		axis = Vector2(0.0 if test_elapsed < 2.2 else sin(test_elapsed * 1.7 + float(NetworkSession.local_peer_id())), 0.0)
		aim = _automated_aim()
		wants_fire = true
		wants_repair = test_elapsed < 2.2
	if NetworkSession.is_host_authority():
		_apply_host_input(NetworkSession.local_peer_id(), input_sequence, axis, aim, wants_fire, wants_repair)
	else:
		local_player.apply_prediction_motion(axis, INPUT_INTERVAL)
		input_history.append({"sequence": input_sequence, "axis": axis})
		if input_history.size() > 180:
			input_history.pop_front()
		if wants_fire and local_player.consume_fire_request():
			coordinator.spawn_cosmetic_projectile(local_player, aim)
		_submit_input.rpc_id(NetworkSession.HOST_PEER_ID, input_sequence, axis, aim, wants_fire, wants_repair)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(sequence: int, axis: Vector2, aim: Vector2, wants_fire: bool, wants_repair: bool) -> void:
	if not NetworkSession.is_host_authority():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not players_by_peer.has(sender_id):
		return
	remote_inputs_received += 1
	_apply_host_input(sender_id, sequence, axis, aim, wants_fire, wants_repair)


func _apply_host_input(peer_id: int, sequence: int, axis: Vector2, aim: Vector2, wants_fire: bool, wants_repair: bool) -> void:
	var previous_sequence: int = int(last_processed_input.get(peer_id, 0))
	if sequence <= previous_sequence:
		return
	last_processed_input[peer_id] = sequence
	var player := players_by_peer.get(peer_id) as CrewPlayer
	if player == null:
		return
	player.apply_network_input(axis, aim, INPUT_INTERVAL, wants_repair)
	if wants_fire and player.consume_fire_request():
		var safe_aim: Vector2 = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
		coordinator.spawn_authoritative_projectile(player, safe_aim)
		confirmed_shots += 1
		_receive_shot_event.rpc(peer_id, player.position, safe_aim)


func _send_player_snapshots() -> void:
	for peer_key: Variant in players_by_peer:
		var peer_id: int = int(peer_key)
		var player := players_by_peer[peer_id] as CrewPlayer
		var aim: Vector2 = player.position.direction_to(player.aim_position)
		_receive_player_snapshot.rpc(
			peer_id, int(last_processed_input.get(peer_id, 0)), player.position,
			aim, player.hp, player.is_downed
		)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_player_snapshot(peer_id: int, ack_sequence: int, authoritative_position: Vector2, aim: Vector2, hp: float, downed: bool) -> void:
	if NetworkSession.is_host_authority():
		return
	var player := players_by_peer.get(peer_id) as CrewPlayer
	if player == null:
		return
	if peer_id == NetworkSession.local_peer_id():
		var predicted_position: Vector2 = player.position
		player.apply_network_snapshot(authoritative_position, aim, hp, downed)
		var pending: Array[Dictionary] = []
		for command: Dictionary in input_history:
			if int(command["sequence"]) > ack_sequence:
				player.apply_prediction_motion(command["axis"] as Vector2, INPUT_INTERVAL)
				pending.append(command)
		input_history = pending
		var correction: float = predicted_position.distance_to(player.position)
		max_correction = maxf(max_correction, correction)
		correction_sum += correction
		correction_count += 1
	else:
		player.apply_network_snapshot(authoritative_position, aim, hp, downed)
		remote_player_snapshot_received.emit(peer_id, authoritative_position)


func _send_enemy_snapshots() -> void:
	for child: Node in coordinator.enemy_director.get_children():
		var enemy := child as EnemyUnit
		if enemy != null and not enemy.is_network_replica:
			_receive_enemy_snapshot.rpc(
				enemy.net_id, String(enemy.enemy_type), enemy.side, enemy.position,
				enemy.hp, enemy.inside_vehicle
			)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_enemy_snapshot(enemy_net_id: int, enemy_id: String, side: int, position_value: Vector2, hp: float, inside_vehicle: bool) -> void:
	if NetworkSession.is_host_authority():
		return
	var enemy: EnemyUnit = coordinator.enemy_director.spawn_network_replica(enemy_net_id, StringName(enemy_id), side)
	enemy.apply_network_snapshot(position_value, hp, inside_vehicle)
	enemy_snapshot_received.emit()


func _on_enemy_removed(enemy_net_id: int) -> void:
	if NetworkSession.is_host_authority():
		_remove_enemy.rpc(enemy_net_id)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _remove_enemy(enemy_net_id: int) -> void:
	coordinator.enemy_director.remove_network_replica(enemy_net_id)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _receive_shot_event(shooter_peer_id: int, origin: Vector2, aim: Vector2) -> void:
	confirmed_shots += 1
	if shooter_peer_id != NetworkSession.local_peer_id():
		coordinator.spawn_cosmetic_projectile_at(origin, aim)


func _send_vehicle_snapshot() -> void:
	var vehicle: VehicleState = coordinator.vehicle_state
	_receive_vehicle_snapshot.rpc(
		vehicle.hull, float(vehicle.section_hp[&"front"]), float(vehicle.section_hp[&"rear"]),
		float(vehicle.section_hp[&"roof"]), float(vehicle.section_hp[&"lower"]), vehicle.supplies,
		coordinator.reward_system.kills
	)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_vehicle_snapshot(hull: float, front: float, rear: float, roof: float, lower: float, supplies: float, kills: int) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.vehicle_state.apply_network_snapshot(hull, front, rear, roof, lower, supplies)
		coordinator.reward_system.kills = kills
		vehicle_snapshot_received.emit(front)


func broadcast_run_state() -> void:
	if NetworkSession.is_host_authority() and remote_sync_ready:
		_receive_run_state.rpc(
			coordinator.stage_director.state,
			coordinator.stage_director.wave_index,
			coordinator.stage_director.state_time
		)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_run_state(state: int, wave_index: int, time_left: float) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.apply_stage_snapshot(state, wave_index, time_left)
		run_state_received.emit(state, wave_index)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_wave_clock(wave_index: int, time_left: float) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.stage_director.wave_index = wave_index
		coordinator.stage_director.state_time = time_left


func broadcast_reward_choices(choices: Array[RelicDefinition]) -> void:
	if choices.size() == 3:
		_receive_reward_choices.rpc(String(choices[0].id), String(choices[1].id), String(choices[2].id))


@rpc("authority", "call_remote", "reliable", 0)
func _receive_reward_choices(first_id: String, second_id: String, third_id: String) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.receive_reward_choices(first_id, second_id, third_id)


func broadcast_relic_selected(relic_id: StringName) -> void:
	_receive_relic_selected.rpc(String(relic_id))


@rpc("authority", "call_remote", "reliable", 0)
func _receive_relic_selected(relic_id: String) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.receive_relic_selected(StringName(relic_id))


func broadcast_result(victory: bool) -> void:
	var relic_ids: Array[String] = ["", "", ""]
	for index: int in mini(3, coordinator.reward_system.acquired.size()):
		relic_ids[index] = String(coordinator.reward_system.acquired[index].id)
	_receive_result.rpc(
		victory, coordinator.reward_system.kills,
		relic_ids[0], relic_ids[1], relic_ids[2]
	)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_result(victory: bool, kills: int, first_relic_id: String, second_relic_id: String, third_relic_id: String) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.receive_result(victory, kills, first_relic_id, second_relic_id, third_relic_id)


func _on_session_failed(_message: String) -> void:
	set_physics_process(false)


func _automated_aim() -> Vector2:
	var closest_distance: float = INF
	var result: Vector2 = Vector2.LEFT
	for child: Node in coordinator.enemy_director.get_children():
		var enemy := child as EnemyUnit
		if enemy == null:
			continue
		var distance: float = local_player.position.distance_to(enemy.position)
		if distance < closest_distance:
			closest_distance = distance
			result = local_player.position.direction_to(enemy.position)
	return result
