class_name PlayerNetReplicator
extends Node

signal remote_player_snapshot_received(peer_id: int, position_value: Vector2)
signal player_survival_snapshot_received(
	peer_id: int, downed: bool, departed: bool, invulnerability: float,
	dodge_cooldown: float, hp: float
)
signal player_ability_snapshot_received(peer_id: int, active_time: float, cooldown: float)

const INPUT_INTERVAL: float = 1.0 / 30.0
const SNAPSHOT_INTERVAL: float = 1.0 / 20.0

var coordinator: RunCoordinator
var players_by_peer: Dictionary = {}
var local_player: CrewPlayer
var input_sequence: int = 0
var input_accumulator: float = 0.0
var snapshot_accumulator: float = 0.0
var last_processed_input: Dictionary = {}
var input_history: Array[Dictionary] = []
var correction_sum: float = 0.0
var correction_count: int = 0
var max_correction: float = 0.0
var remote_inputs_received: int = 0
var confirmed_shots: int = 0
var test_elapsed: float = 0.0
var jump_intent_frames: int = 0
var drop_intent_frames: int = 0
var dodge_intent_frames: int = 0
var remote_dodge_intents_received: int = 0
var dodges_confirmed: int = 0
var remote_ability_intents_received: int = 0
var abilities_confirmed: int = 0
var automated_test: bool = false
var initialized: bool = false


func setup(run: RunCoordinator, players: Dictionary) -> void:
	coordinator = run
	players_by_peer = players
	local_player = players_by_peer.get(NetworkSession.local_peer_id()) as CrewPlayer
	automated_test = OS.get_cmdline_user_args().has("--network-test-host") or OS.get_cmdline_user_args().has("--network-test-client")
	NetworkSession.session_failed.connect(_on_session_failed)
	initialized = true


func _physics_process(delta: float) -> void:
	if not initialized or local_player == null:
		return
	test_elapsed += delta
	if NetworkSession.is_host_authority():
		for peer_key: Variant in players_by_peer:
			(players_by_peer[peer_key] as CrewPlayer).authority_tick(delta)
		coordinator.revive_controller.authority_tick(delta, test_elapsed)
	else:
		local_player.client_tick(delta)
	input_accumulator += delta
	if input_accumulator >= INPUT_INTERVAL:
		input_accumulator -= INPUT_INTERVAL
		_capture_local_input()
	if not NetworkSession.is_host_authority():
		return
	snapshot_accumulator += delta
	if snapshot_accumulator >= SNAPSHOT_INTERVAL:
		snapshot_accumulator -= SNAPSHOT_INTERVAL
		_send_player_snapshots()


func _capture_local_input() -> void:
	input_sequence += 1
	var axis := Vector2(Input.get_axis(&"move_left", &"move_right"), 0.0)
	if Input.is_action_just_pressed(&"jump"): jump_intent_frames = 3
	if Input.is_action_just_pressed(&"drop_down"): drop_intent_frames = 3
	if jump_intent_frames > 0:
		axis.y = -1.0
		jump_intent_frames -= 1
	elif drop_intent_frames > 0:
		axis.y = 1.0
		drop_intent_frames -= 1
	if Input.is_action_just_pressed(&"dodge"): dodge_intent_frames = 3
	var wants_dodge: bool = dodge_intent_frames > 0
	dodge_intent_frames = maxi(0, dodge_intent_frames - 1)
	var aim: Vector2 = local_player.position.direction_to(local_player.get_global_mouse_position())
	var wants_fire: bool = Input.is_action_pressed(&"fire_primary")
	var wants_interact: bool = Input.is_action_pressed(&"interact")
	var wants_ability: bool = Input.is_action_just_pressed(&"ability")
	if automated_test:
		axis = Vector2(0.0 if test_elapsed < 8.0 else sin(test_elapsed * 1.7 + float(NetworkSession.local_peer_id())), 0.0)
		if test_elapsed >= 1.2 and test_elapsed < 8.0: axis = _automated_revive_axis()
		aim = _automated_aim()
		wants_fire = true
		wants_interact = test_elapsed >= 1.2 and test_elapsed < 8.0
		# 2プロセスの起動時刻差があっても、ホストが回避意図を確実に受信できる幅を持たせる。
		wants_dodge = test_elapsed >= 0.45 and test_elapsed < 1.10
		wants_ability = test_elapsed >= 0.25 and test_elapsed < 0.40
	if NetworkSession.is_host_authority():
		_apply_host_input(NetworkSession.local_peer_id(), input_sequence, axis, aim, wants_fire, wants_interact, wants_dodge, wants_ability)
	else:
		local_player.apply_prediction_motion(axis, INPUT_INTERVAL)
		input_history.append({"sequence": input_sequence, "axis": axis})
		if input_history.size() > 180: input_history.pop_front()
		if wants_fire and local_player.consume_fire_request(): coordinator.spawn_cosmetic_projectile(local_player, aim)
		_submit_input.rpc_id(NetworkSession.HOST_PEER_ID, input_sequence, axis, aim, wants_fire, wants_interact, wants_dodge, wants_ability)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(sequence: int, axis: Vector2, aim: Vector2, wants_fire: bool, wants_interact: bool, wants_dodge: bool, wants_ability: bool) -> void:
	if not NetworkSession.is_host_authority(): return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not players_by_peer.has(sender_id): return
	remote_inputs_received += 1
	if wants_dodge: remote_dodge_intents_received += 1
	if wants_ability: remote_ability_intents_received += 1
	_apply_host_input(sender_id, sequence, axis, aim, wants_fire, wants_interact, wants_dodge, wants_ability)


func _apply_host_input(peer_id: int, sequence: int, axis: Vector2, aim: Vector2, wants_fire: bool, wants_interact: bool, wants_dodge: bool, wants_ability: bool) -> void:
	if sequence <= int(last_processed_input.get(peer_id, 0)): return
	last_processed_input[peer_id] = sequence
	var player := players_by_peer.get(peer_id) as CrewPlayer
	if player == null: return
	player.apply_network_input(axis, aim, INPUT_INTERVAL, wants_interact)
	if wants_dodge and player.authority_request_dodge(axis, aim): dodges_confirmed += 1
	if wants_ability and player.authority_request_ability(): abilities_confirmed += 1
	coordinator.revive_controller.handle_interact_intent(peer_id, player, wants_interact, test_elapsed, INPUT_INTERVAL)
	if wants_fire and player.consume_fire_request():
		var safe_aim: Vector2 = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
		coordinator.spawn_authoritative_projectile(player, safe_aim)
		confirmed_shots += 1
		_receive_shot_event.rpc(peer_id, player.position, safe_aim, String(player.weapon_definition.id))


func _send_player_snapshots() -> void:
	for peer_key: Variant in players_by_peer:
		var peer_id: int = int(peer_key)
		var player := players_by_peer[peer_id] as CrewPlayer
		_receive_player_snapshot.rpc(
			peer_id, int(last_processed_input.get(peer_id, 0)), player.position,
			player.position.direction_to(player.aim_position), player.survival.hp,
			player.survival.is_downed, player.survival.is_departed,
			player.survival.invulnerable_time, player.survival.dodge_cooldown,
			player.survival.downed_time, player.survival.return_time, player.survival.revive_progress,
			player.ability_active_time, player.ability_cooldown
		)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_player_snapshot(peer_id: int, ack_sequence: int, authoritative_position: Vector2, aim: Vector2, hp: float, downed: bool, departed: bool, invulnerability: float, dodge_cooldown_value: float, down_time: float, return_time_value: float, revive_progress_value: float, ability_active_value: float, ability_cooldown_value: float) -> void:
	if NetworkSession.is_host_authority(): return
	var player := players_by_peer.get(peer_id) as CrewPlayer
	if player == null: return
	if peer_id == NetworkSession.local_peer_id():
		var predicted_position: Vector2 = player.position
		player.apply_network_snapshot(authoritative_position, aim, hp, downed, departed, invulnerability, dodge_cooldown_value, down_time, return_time_value, revive_progress_value, ability_active_value, ability_cooldown_value)
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
		player.apply_network_snapshot(authoritative_position, aim, hp, downed, departed, invulnerability, dodge_cooldown_value, down_time, return_time_value, revive_progress_value, ability_active_value, ability_cooldown_value)
		remote_player_snapshot_received.emit(peer_id, authoritative_position)
	player_survival_snapshot_received.emit(peer_id, downed, departed, invulnerability, dodge_cooldown_value, hp)
	player_ability_snapshot_received.emit(peer_id, ability_active_value, ability_cooldown_value)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _receive_shot_event(shooter_peer_id: int, origin: Vector2, aim: Vector2, weapon_id: String) -> void:
	confirmed_shots += 1
	if shooter_peer_id != NetworkSession.local_peer_id(): coordinator.spawn_cosmetic_projectile_at(origin, aim, StringName(weapon_id))


func _automated_aim() -> Vector2:
	var closest_distance: float = INF
	var result: Vector2 = Vector2.LEFT
	for child: Node in coordinator.enemy_director.get_children():
		var enemy := child as EnemyUnit
		if enemy != null and local_player.position.distance_to(enemy.position) < closest_distance:
			closest_distance = local_player.position.distance_to(enemy.position)
			result = local_player.position.direction_to(enemy.position)
	return result


func _automated_revive_axis() -> Vector2:
	for peer_key: Variant in players_by_peer:
		var teammate := players_by_peer[peer_key] as CrewPlayer
		if teammate != local_player and teammate.survival.is_downed:
			var offset_x: float = teammate.position.x - local_player.position.x
			if absf(offset_x) > local_player.definition.revive_interaction_range_px * 0.5: return Vector2(signf(offset_x), 0.0)
	return Vector2.ZERO


func _on_session_failed(_message: String) -> void:
	set_physics_process(false)
