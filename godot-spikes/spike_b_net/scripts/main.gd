extends Node2D

const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_PORT: int = 29117
const HOST_PEER_ID: int = 1
const MAX_CLIENTS: int = 1
const CHANNEL_COUNT: int = 4
const PLAYER_SPEED: float = 220.0
const PLAYER_RADIUS: float = 18.0
const ENEMY_SPEED: float = 34.0
const ENEMY_MAX_HP: int = 5
const ENEMY_COUNT: int = 10
const SHOT_COOLDOWN: float = 0.18
const SHOT_RANGE: float = 760.0
const HIT_RADIUS: float = 28.0
const INPUT_INTERVAL: float = 1.0 / 30.0
const PLAYER_SNAPSHOT_INTERVAL: float = 1.0 / 20.0
const ENEMY_SNAPSHOT_INTERVAL: float = 1.0 / 12.0
const WORLD_RECT := Rect2(40.0, 110.0, 880.0, 390.0)

var role: String = "host"
var address: String = DEFAULT_ADDRESS
var port: int = DEFAULT_PORT
var duration_seconds: float = 30.0
var report_path: String = ""
var automated: bool = true
var elapsed_seconds: float = 0.0
var connected: bool = false
var had_remote_peer: bool = false
var remote_peer_id: int = 0
var status_text: String = "起動中"
var simulation_finishing: bool = false
var finish_wait_seconds: float = 0.0
var final_ack_received: bool = false
var final_hash_matched: bool = false
var completion_started: bool = false

var players: Dictionary = {}
var enemies: Array[Dictionary] = []
var client_enemy_targets: Array[Dictionary] = []
var input_history: Array[Dictionary] = []
var input_sequence: int = 0
var last_processed_input: Dictionary = {}
var local_aim := Vector2.RIGHT
var input_accumulator: float = 0.0
var player_snapshot_accumulator: float = 0.0
var enemy_snapshot_accumulator: float = 0.0
var shot_cooldowns: Dictionary = {}
var client_shot_cooldown: float = 0.0
var client_max_correction: float = 0.0
var client_correction_sum: float = 0.0
var client_correction_count: int = 0
var shots_requested: int = 0
var shots_confirmed: int = 0
var hits_confirmed: int = 0
var enemy_respawns: int = 0
var disconnects: int = 0
var desync_count: int = 0
var test_started_ms: int = 0
var shot_lines: Array[Dictionary] = []

var impairment := NetworkImpairment.new(0xB17E)


func _ready() -> void:
	_parse_arguments()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	if role == "host":
		_start_host()
	else:
		_start_client()
	queue_redraw()


func _physics_process(delta: float) -> void:
	impairment.process_pending()
	_update_shot_lines(delta)
	if simulation_finishing:
		_process_finish_wait(delta)
		queue_redraw()
		return
	if not connected:
		queue_redraw()
		return
	elapsed_seconds += delta
	if role == "host":
		_host_simulation(delta)
	else:
		_client_simulation(delta)
	if role == "host" and duration_seconds > 0.0 and elapsed_seconds >= duration_seconds:
		_begin_final_validation()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color("101722"))
	draw_rect(WORLD_RECT, Color("172433"), true)
	draw_rect(WORLD_RECT, Color("456078"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 38.0), "Spike B: ENet host authority", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color("e8f1ff"))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 70.0), "role=%s  %s  t=%.1fs" % [role, status_text, elapsed_seconds], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color("8fd3ff"))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 94.0), "RTT=150ms loss=2%%  shots=%d hits=%d" % [shots_confirmed, hits_confirmed], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("aabdd0"))
	for enemy: Dictionary in enemies:
		var enemy_position: Vector2 = enemy["position"] as Vector2
		var hp: int = int(enemy["hp"])
		var enemy_color := Color("cf5264") if hp > 0 else Color("3a4450")
		draw_circle(enemy_position, 16.0, enemy_color)
		draw_rect(Rect2(enemy_position + Vector2(-18.0, -26.0), Vector2(36.0 * float(hp) / ENEMY_MAX_HP, 4.0)), Color("80d889"), true)
	for peer_key: Variant in players:
		var peer_id: int = int(peer_key)
		var state: Dictionary = players[peer_id] as Dictionary
		var player_position: Vector2 = state["position"] as Vector2
		var player_color := Color("58b7ff") if peer_id == HOST_PEER_ID else Color("ffd166")
		draw_circle(player_position, PLAYER_RADIUS, player_color)
		draw_line(player_position, player_position + (state["aim"] as Vector2) * 30.0, Color.WHITE, 4.0)
	for line: Dictionary in shot_lines:
		draw_line(line["from"] as Vector2, line["to"] as Vector2, line["color"] as Color, 3.0)


func _parse_arguments() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument == "--host":
			role = "host"
		elif argument == "--client":
			role = "client"
		elif argument == "--manual":
			automated = false
		elif argument == "--no-impairment":
			impairment.enabled = false
		elif argument.begins_with("--address="):
			address = argument.trim_prefix("--address=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
		elif argument.begins_with("--duration="):
			duration_seconds = argument.trim_prefix("--duration=").to_float()
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")


func _start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENTS, CHANNEL_COUNT)
	if error != OK:
		_fail_and_quit("ENetサーバーを開始できません: %s" % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	players[HOST_PEER_ID] = _make_player_state(Vector2(260.0, 270.0))
	_spawn_enemies()
	status_text = "待受中 port=%d" % port
	print("SPIKE_B_HOST_READY port=%d" % port)


func _start_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port, CHANNEL_COUNT)
	if error != OK:
		_fail_and_quit("ENetクライアントを開始できません: %s" % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	status_text = "接続中 %s:%d" % [address, port]
	print("SPIKE_B_CLIENT_CONNECTING address=%s port=%d" % [address, port])


func _host_simulation(delta: float) -> void:
	if not had_remote_peer:
		return
	var host_axis: Vector2 = _automated_axis(0.0) if automated else _read_manual_axis()
	_apply_host_player_motion(HOST_PEER_ID, host_axis, delta)
	if automated:
		var host_state: Dictionary = players[HOST_PEER_ID] as Dictionary
		host_state["aim"] = Vector2.RIGHT
		players[HOST_PEER_ID] = host_state
	_update_host_shot_cooldowns(delta)
	_update_enemies(delta)
	if automated and fmod(elapsed_seconds, 0.72) < delta:
		_host_process_shot(HOST_PEER_ID, Vector2.RIGHT)
	player_snapshot_accumulator += delta
	enemy_snapshot_accumulator += delta
	if player_snapshot_accumulator >= PLAYER_SNAPSHOT_INTERVAL:
		player_snapshot_accumulator -= PLAYER_SNAPSHOT_INTERVAL
		_queue_player_snapshot()
	if enemy_snapshot_accumulator >= ENEMY_SNAPSHOT_INTERVAL:
		enemy_snapshot_accumulator -= ENEMY_SNAPSHOT_INTERVAL
		_queue_enemy_snapshot()


func _client_simulation(delta: float) -> void:
	if not players.has(multiplayer.get_unique_id()):
		return
	client_shot_cooldown = maxf(0.0, client_shot_cooldown - delta)
	var axis: Vector2 = _automated_axis(1.7) if automated else _read_manual_axis()
	local_aim = Vector2.RIGHT if automated else _read_manual_aim()
	_predict_local_player(axis, delta)
	input_accumulator += delta
	if input_accumulator >= INPUT_INTERVAL:
		input_accumulator -= INPUT_INTERVAL
		_send_client_input(axis)
	if automated and client_shot_cooldown <= 0.0:
		_request_client_shot()
	elif not automated and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and client_shot_cooldown <= 0.0:
		_request_client_shot()
	_interpolate_client_enemies(delta)


func _make_player_state(spawn_position: Vector2) -> Dictionary:
	return {
		"position": spawn_position,
		"velocity": Vector2.ZERO,
		"aim": Vector2.RIGHT,
		"ack": 0,
	}


func _spawn_enemies() -> void:
	enemies.clear()
	for index: int in ENEMY_COUNT:
		enemies.append({
			"id": index,
			"position": Vector2(610.0 + float(index % 5) * 58.0, 155.0 + float(index / 5) * 220.0),
			"hp": ENEMY_MAX_HP,
			"respawn": 0.0,
		})


func _automated_axis(phase_offset: float) -> Vector2:
	return Vector2(cos(elapsed_seconds * 0.83 + phase_offset), sin(elapsed_seconds * 1.11 + phase_offset)).normalized()


func _read_manual_axis() -> Vector2:
	var axis := Vector2.ZERO
	axis.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	axis.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return axis.normalized() if axis.length_squared() > 1.0 else axis


func _read_manual_aim() -> Vector2:
	var own_id: int = multiplayer.get_unique_id()
	var state: Dictionary = players.get(own_id, _make_player_state(Vector2.ZERO)) as Dictionary
	var direction: Vector2 = get_global_mouse_position() - (state["position"] as Vector2)
	return direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT


func _apply_host_player_motion(peer_id: int, axis: Vector2, delta: float) -> void:
	if not players.has(peer_id):
		return
	var state: Dictionary = players[peer_id] as Dictionary
	var safe_axis: Vector2 = axis.limit_length(1.0)
	state["velocity"] = safe_axis * PLAYER_SPEED
	state["position"] = _clamp_to_world((state["position"] as Vector2) + (state["velocity"] as Vector2) * delta)
	players[peer_id] = state


func _predict_local_player(axis: Vector2, delta: float) -> void:
	var own_id: int = multiplayer.get_unique_id()
	var state: Dictionary = players[own_id] as Dictionary
	state["velocity"] = axis.limit_length(1.0) * PLAYER_SPEED
	state["position"] = _clamp_to_world((state["position"] as Vector2) + (state["velocity"] as Vector2) * delta)
	state["aim"] = local_aim
	players[own_id] = state


func _send_client_input(axis: Vector2) -> void:
	input_sequence += 1
	var command := {
		"sequence": input_sequence,
		"axis": axis.limit_length(1.0),
		"aim": local_aim,
		"delta": INPUT_INTERVAL,
	}
	input_history.append(command)
	if input_history.size() > 180:
		input_history.pop_front()
	var action: Callable = _send_input_now.bind(input_sequence, command["axis"], local_aim)
	impairment.enqueue_unreliable(action, _estimate_bytes([input_sequence, command["axis"], local_aim]))


func _send_input_now(sequence: int, axis: Vector2, aim: Vector2) -> void:
	submit_input.rpc_id(HOST_PEER_ID, sequence, axis, aim)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(sequence: int, axis: Vector2, aim: Vector2) -> void:
	if role != "host":
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0 or not players.has(sender_id):
		return
	var previous_sequence: int = int(last_processed_input.get(sender_id, 0))
	if sequence <= previous_sequence:
		return
	last_processed_input[sender_id] = sequence
	var state: Dictionary = players[sender_id] as Dictionary
	var safe_axis: Vector2 = axis.limit_length(1.0)
	state["velocity"] = safe_axis * PLAYER_SPEED
	state["position"] = _clamp_to_world((state["position"] as Vector2) + (state["velocity"] as Vector2) * INPUT_INTERVAL)
	state["aim"] = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	state["ack"] = sequence
	players[sender_id] = state


func _queue_player_snapshot() -> void:
	if remote_peer_id == 0:
		return
	var snapshot: Array = []
	for peer_key: Variant in players:
		var peer_id: int = int(peer_key)
		var state: Dictionary = players[peer_id] as Dictionary
		snapshot.append([peer_id, state["position"], state["velocity"], state["aim"], state["ack"]])
	var action: Callable = _send_player_snapshot_now.bind(remote_peer_id, snapshot)
	impairment.enqueue_unreliable(action, _estimate_bytes(snapshot))


func _send_player_snapshot_now(peer_id: int, snapshot: Array) -> void:
	receive_player_snapshot.rpc_id(peer_id, snapshot)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_player_snapshot(snapshot: Array) -> void:
	if role != "client":
		return
	var own_id: int = multiplayer.get_unique_id()
	for row_variant: Variant in snapshot:
		var row: Array = row_variant as Array
		var peer_id: int = int(row[0])
		var authoritative_position: Vector2 = row[1] as Vector2
		if peer_id == own_id and players.has(peer_id):
			_reconcile_local_player(authoritative_position, row[2] as Vector2, row[3] as Vector2, int(row[4]))
		else:
			players[peer_id] = {
				"position": authoritative_position,
				"velocity": row[2] as Vector2,
				"aim": row[3] as Vector2,
				"ack": int(row[4]),
			}


func _reconcile_local_player(authoritative_position: Vector2, velocity: Vector2, aim: Vector2, ack_sequence: int) -> void:
	var own_id: int = multiplayer.get_unique_id()
	var current: Dictionary = players[own_id] as Dictionary
	var predicted_position: Vector2 = current["position"] as Vector2
	current["position"] = authoritative_position
	current["velocity"] = velocity
	current["aim"] = aim
	current["ack"] = ack_sequence
	var pending_inputs: Array[Dictionary] = []
	for command: Dictionary in input_history:
		if int(command["sequence"]) > ack_sequence:
			current["position"] = _clamp_to_world((current["position"] as Vector2) + (command["axis"] as Vector2) * PLAYER_SPEED * float(command["delta"]))
			pending_inputs.append(command)
	input_history = pending_inputs
	var correction: float = predicted_position.distance_to(current["position"] as Vector2)
	client_max_correction = maxf(client_max_correction, correction)
	client_correction_sum += correction
	client_correction_count += 1
	players[own_id] = current


func _queue_enemy_snapshot() -> void:
	if remote_peer_id == 0:
		return
	var snapshot: Array = []
	for enemy: Dictionary in enemies:
		snapshot.append([enemy["id"], enemy["position"], enemy["hp"]])
	var action: Callable = _send_enemy_snapshot_now.bind(remote_peer_id, snapshot)
	impairment.enqueue_unreliable(action, _estimate_bytes(snapshot))


func _send_enemy_snapshot_now(peer_id: int, snapshot: Array) -> void:
	receive_enemy_snapshot.rpc_id(peer_id, snapshot)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_enemy_snapshot(snapshot: Array) -> void:
	if role != "client":
		return
	client_enemy_targets.clear()
	for row_variant: Variant in snapshot:
		var row: Array = row_variant as Array
		client_enemy_targets.append({"id": int(row[0]), "position": row[1] as Vector2, "hp": int(row[2])})
	if enemies.is_empty():
		enemies = client_enemy_targets.duplicate(true)


func _interpolate_client_enemies(delta: float) -> void:
	for target: Dictionary in client_enemy_targets:
		var enemy_id: int = int(target["id"])
		if enemy_id < 0 or enemy_id >= enemies.size():
			continue
		var shown: Dictionary = enemies[enemy_id]
		shown["position"] = (shown["position"] as Vector2).lerp(target["position"] as Vector2, minf(1.0, delta / 0.1))
		shown["hp"] = int(target["hp"])
		enemies[enemy_id] = shown


func _update_enemies(delta: float) -> void:
	var target_position := Vector2(330.0, 300.0)
	for index: int in enemies.size():
		var enemy: Dictionary = enemies[index]
		if int(enemy["hp"]) <= 0:
			enemy["respawn"] = float(enemy["respawn"]) - delta
			if float(enemy["respawn"]) <= 0.0:
				enemy["hp"] = ENEMY_MAX_HP
				enemy["position"] = Vector2(760.0 + float(index % 4) * 45.0, 140.0 + float(index) * 34.0)
				enemy_respawns += 1
			enemies[index] = enemy
			continue
		var position: Vector2 = enemy["position"] as Vector2
		var direction: Vector2 = position.direction_to(target_position)
		enemy["position"] = _clamp_to_world(position + direction * ENEMY_SPEED * delta)
		enemies[index] = enemy


func _request_client_shot() -> void:
	client_shot_cooldown = SHOT_COOLDOWN
	shots_requested += 1
	var own_id: int = multiplayer.get_unique_id()
	var state: Dictionary = players[own_id] as Dictionary
	var origin: Vector2 = state["position"] as Vector2
	shot_lines.append({"from": origin, "to": origin + local_aim * 120.0, "color": Color("ffe299"), "life": 0.06})
	var action: Callable = _send_shot_intent_now.bind(local_aim)
	impairment.enqueue_unreliable(action, _estimate_bytes(local_aim))


func _send_shot_intent_now(aim: Vector2) -> void:
	request_shot.rpc_id(HOST_PEER_ID, aim)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func request_shot(aim: Vector2) -> void:
	if role != "host":
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_host_process_shot(sender_id, aim)


func _host_process_shot(shooter_id: int, aim: Vector2) -> void:
	if not players.has(shooter_id) or float(shot_cooldowns.get(shooter_id, 0.0)) > 0.0:
		return
	var direction: Vector2 = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	var shooter: Dictionary = players[shooter_id] as Dictionary
	var origin: Vector2 = shooter["position"] as Vector2
	var hit_enemy_id: int = _find_hit_enemy(origin, direction)
	if hit_enemy_id >= 0:
		var enemy: Dictionary = enemies[hit_enemy_id]
		enemy["hp"] = maxi(0, int(enemy["hp"]) - 1)
		if int(enemy["hp"]) == 0:
			enemy["respawn"] = 1.0
		enemies[hit_enemy_id] = enemy
		hits_confirmed += 1
	shot_cooldowns[shooter_id] = SHOT_COOLDOWN
	shots_confirmed += 1
	var end_position: Vector2 = origin + direction * SHOT_RANGE
	shot_lines.append({"from": origin, "to": end_position, "color": Color("ffefb0"), "life": 0.08})
	if remote_peer_id != 0:
		var action: Callable = _send_shot_event_now.bind(remote_peer_id, shooter_id, origin, end_position, hit_enemy_id)
		impairment.enqueue_unreliable(action, _estimate_bytes([shooter_id, origin, end_position, hit_enemy_id]))


func _find_hit_enemy(origin: Vector2, direction: Vector2) -> int:
	var best_id: int = -1
	var best_distance: float = SHOT_RANGE
	for enemy: Dictionary in enemies:
		if int(enemy["hp"]) <= 0:
			continue
		var offset: Vector2 = (enemy["position"] as Vector2) - origin
		var along: float = offset.dot(direction)
		if along < 0.0 or along > best_distance:
			continue
		var perpendicular: float = absf(offset.cross(direction))
		if perpendicular <= HIT_RADIUS:
			best_distance = along
			best_id = int(enemy["id"])
	return best_id


func _send_shot_event_now(peer_id: int, shooter_id: int, origin: Vector2, end_position: Vector2, hit_enemy_id: int) -> void:
	receive_shot_event.rpc_id(peer_id, shooter_id, origin, end_position, hit_enemy_id)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func receive_shot_event(_shooter_id: int, origin: Vector2, end_position: Vector2, hit_enemy_id: int) -> void:
	shots_confirmed += 1
	if hit_enemy_id >= 0:
		hits_confirmed += 1
	shot_lines.append({"from": origin, "to": end_position, "color": Color("ffefb0"), "life": 0.08})


func _update_host_shot_cooldowns(delta: float) -> void:
	for peer_key: Variant in shot_cooldowns.keys():
		var peer_id: int = int(peer_key)
		shot_cooldowns[peer_id] = maxf(0.0, float(shot_cooldowns[peer_id]) - delta)


func _update_shot_lines(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for line: Dictionary in shot_lines:
		line["life"] = float(line["life"]) - delta
		if float(line["life"]) > 0.0:
			remaining.append(line)
	shot_lines = remaining


func _queue_initial_state(peer_id: int) -> void:
	var initial_players: Array = []
	for peer_key: Variant in players:
		var id: int = int(peer_key)
		var state: Dictionary = players[id] as Dictionary
		initial_players.append([id, state["position"], state["velocity"], state["aim"], state["ack"]])
	var initial_enemies: Array = []
	for enemy: Dictionary in enemies:
		initial_enemies.append([enemy["id"], enemy["position"], enemy["hp"]])
	var action: Callable = _send_initial_state_now.bind(peer_id, initial_players, initial_enemies)
	impairment.enqueue_reliable(action, _estimate_bytes([initial_players, initial_enemies]))


func _send_initial_state_now(peer_id: int, initial_players: Array, initial_enemies: Array) -> void:
	receive_initial_state.rpc_id(peer_id, initial_players, initial_enemies)


@rpc("authority", "call_remote", "reliable", 0)
func receive_initial_state(initial_players: Array, initial_enemies: Array) -> void:
	players.clear()
	for row_variant: Variant in initial_players:
		var row: Array = row_variant as Array
		players[int(row[0])] = {"position": row[1] as Vector2, "velocity": row[2] as Vector2, "aim": row[3] as Vector2, "ack": int(row[4])}
	enemies.clear()
	for row_variant: Variant in initial_enemies:
		var row: Array = row_variant as Array
		enemies.append({"id": int(row[0]), "position": row[1] as Vector2, "hp": int(row[2]), "respawn": 0.0})
	client_enemy_targets = enemies.duplicate(true)
	test_started_ms = Time.get_ticks_msec()
	status_text = "初期同期済み"
	print("SPIKE_B_INITIAL_STATE players=%d enemies=%d" % [players.size(), enemies.size()])


func _begin_final_validation() -> void:
	simulation_finishing = true
	finish_wait_seconds = 0.0
	status_text = "最終整合性検証中"
	var state_hash: String = _authoritative_state_hash()
	var final_players: Array = []
	for peer_key: Variant in players:
		var id: int = int(peer_key)
		var state: Dictionary = players[id] as Dictionary
		final_players.append([id, state["position"], state["velocity"], state["aim"], state["ack"]])
	var final_enemies: Array = []
	for enemy: Dictionary in enemies:
		final_enemies.append([enemy["id"], enemy["position"], enemy["hp"]])
	var action: Callable = _send_final_state_now.bind(remote_peer_id, state_hash, final_players, final_enemies)
	impairment.enqueue_reliable(action, _estimate_bytes([state_hash, final_players, final_enemies]))
	print("SPIKE_B_FINAL_VALIDATION_STARTED hash=%s" % state_hash)


func _send_final_state_now(peer_id: int, state_hash: String, final_players: Array, final_enemies: Array) -> void:
	receive_final_state.rpc_id(peer_id, state_hash, final_players, final_enemies)


@rpc("authority", "call_remote", "reliable", 0)
func receive_final_state(host_hash: String, final_players: Array, final_enemies: Array) -> void:
	simulation_finishing = true
	players.clear()
	for row_variant: Variant in final_players:
		var row: Array = row_variant as Array
		players[int(row[0])] = {"position": row[1] as Vector2, "velocity": row[2] as Vector2, "aim": row[3] as Vector2, "ack": int(row[4])}
	enemies.clear()
	for row_variant: Variant in final_enemies:
		var row: Array = row_variant as Array
		enemies.append({"id": int(row[0]), "position": row[1] as Vector2, "hp": int(row[2]), "respawn": 0.0})
	var client_hash: String = _authoritative_state_hash()
	var action: Callable = _send_final_ack_now.bind(host_hash, client_hash, client_max_correction, client_correction_sum / maxf(1.0, float(client_correction_count)))
	impairment.enqueue_reliable(action, _estimate_bytes([host_hash, client_hash, client_max_correction]))


func _send_final_ack_now(host_hash: String, client_hash: String, max_correction: float, average_correction: float) -> void:
	final_ack.rpc_id(HOST_PEER_ID, host_hash, client_hash, max_correction, average_correction)


@rpc("any_peer", "call_remote", "reliable", 0)
func final_ack(host_hash: String, client_hash: String, max_correction: float, average_correction: float) -> void:
	if role != "host":
		return
	final_ack_received = true
	final_hash_matched = host_hash == client_hash
	if not final_hash_matched:
		desync_count += 1
	client_max_correction = max_correction
	client_correction_sum = average_correction
	client_correction_count = 1
	print("SPIKE_B_FINAL_ACK matched=%s max_correction=%.3f avg_correction=%.3f" % [final_hash_matched, max_correction, average_correction])


func _process_finish_wait(delta: float) -> void:
	finish_wait_seconds += delta
	if role == "client":
		return
	if final_ack_received and finish_wait_seconds >= 0.5:
		_complete_test()
	elif finish_wait_seconds >= 5.0:
		_complete_test()


func _complete_test() -> void:
	if completion_started:
		return
	completion_started = true
	var succeeded: bool = had_remote_peer and final_ack_received and final_hash_matched and disconnects == 0 and enemies.size() == ENEMY_COUNT and shots_confirmed > 0
	var report: Dictionary = _build_report(succeeded)
	_write_report(report)
	print("SPIKE_B_TEST_RESULT %s" % JSON.stringify(report))
	if remote_peer_id != 0 and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		finish_test.rpc_id(remote_peer_id, succeeded)
	get_tree().create_timer(0.25).timeout.connect(func() -> void: get_tree().quit(0 if succeeded else 3))


@rpc("authority", "call_remote", "reliable", 0)
func finish_test(succeeded: bool) -> void:
	print("SPIKE_B_CLIENT_FINISH success=%s" % succeeded)
	get_tree().quit(0 if succeeded else 3)


func _build_report(succeeded: bool) -> Dictionary:
	var average_correction: float = client_correction_sum / maxf(1.0, float(client_correction_count))
	return {
		"success": succeeded,
		"duration_seconds": snappedf(elapsed_seconds, 0.001),
		"rtt_ms": impairment.one_way_delay_ms * 2 if impairment.enabled else 0,
		"packet_loss_percent": impairment.packet_loss_rate * 100.0 if impairment.enabled else 0.0,
		"players": players.size(),
		"enemies": enemies.size(),
		"shots_confirmed": shots_confirmed,
		"hits_confirmed": hits_confirmed,
		"enemy_respawns": enemy_respawns,
		"disconnects": disconnects,
		"desync_count": desync_count,
		"final_hash_matched": final_hash_matched,
		"unreliable_sent": impairment.unreliable_sent,
		"unreliable_dropped": impairment.unreliable_dropped,
		"reliable_sent": impairment.reliable_sent,
		"reliable_retries": impairment.reliable_retries,
		"estimated_payload_bytes": impairment.estimated_bytes_sent,
		"estimated_payload_kbps": snappedf(float(impairment.estimated_bytes_sent) * 8.0 / maxf(1.0, elapsed_seconds) / 1000.0, 0.001),
		"client_max_correction_px": snappedf(client_max_correction, 0.001),
		"client_average_correction_px": snappedf(average_correction, 0.001),
	}


func _write_report(report: Dictionary) -> void:
	if report_path.is_empty():
		return
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("レポートを書き込めません: %s" % report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _authoritative_state_hash() -> String:
	var parts: PackedStringArray = []
	var peer_ids: Array = players.keys()
	peer_ids.sort()
	for peer_key: Variant in peer_ids:
		var peer_id: int = int(peer_key)
		var state: Dictionary = players[peer_id] as Dictionary
		var position: Vector2 = state["position"] as Vector2
		parts.append("p:%d:%.3f:%.3f:%d" % [peer_id, position.x, position.y, int(state["ack"])])
	for enemy: Dictionary in enemies:
		var position: Vector2 = enemy["position"] as Vector2
		parts.append("e:%d:%.3f:%.3f:%d" % [int(enemy["id"]), position.x, position.y, int(enemy["hp"])])
	return "|".join(parts).sha256_text()


func _estimate_bytes(value: Variant) -> int:
	return var_to_bytes(value).size()


func _clamp_to_world(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, WORLD_RECT.position.x + PLAYER_RADIUS, WORLD_RECT.end.x - PLAYER_RADIUS),
		clampf(position.y, WORLD_RECT.position.y + PLAYER_RADIUS, WORLD_RECT.end.y - PLAYER_RADIUS)
	)


func _on_peer_connected(peer_id: int) -> void:
	connected = true
	had_remote_peer = true
	remote_peer_id = peer_id
	status_text = "接続済み peer=%d" % peer_id
	if role == "host":
		players[peer_id] = _make_player_state(Vector2(210.0, 350.0))
		shot_cooldowns[peer_id] = 0.0
		test_started_ms = Time.get_ticks_msec()
		_queue_initial_state(peer_id)
	print("SPIKE_B_PEER_CONNECTED role=%s peer=%d" % [role, peer_id])


func _on_peer_disconnected(peer_id: int) -> void:
	connected = false
	if not simulation_finishing:
		disconnects += 1
	status_text = "切断 peer=%d" % peer_id
	print("SPIKE_B_PEER_DISCONNECTED role=%s peer=%d" % [role, peer_id])


func _on_connected_to_server() -> void:
	connected = true
	status_text = "ホストへ接続済み"
	print("SPIKE_B_CLIENT_CONNECTED own_id=%d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	connected = false
	_fail_and_quit("ホストへの接続に失敗しました")


func _fail_and_quit(message: String) -> void:
	push_error(message)
	print("SPIKE_B_FATAL %s" % message)
	get_tree().quit(2)
