class_name NetStateReplicator
extends Node

signal enemy_snapshot_received
signal enemy_invasion_snapshot_received(enemy_net_id: int, inside_vehicle: bool, invasion_state: int)
signal vehicle_snapshot_received(front_hp: float)
signal breach_snapshot_received(front: bool, rear: bool, roof: bool, lower: bool)
signal run_state_received(state: int, wave_index: int)
signal route_choices_received(first_id: StringName, second_id: StringName)
signal route_selected_received(route_id: StringName)
signal reward_choices_received(first_id: StringName, second_id: StringName, third_id: StringName)
signal relic_selected_received(relic_id: StringName)
signal route_reward_received

const ENEMY_SNAPSHOT_INTERVAL: float = 1.0 / 12.0
const VEHICLE_SNAPSHOT_INTERVAL: float = 0.5
const WAVE_CLOCK_INTERVAL: float = 1.0

var coordinator: RunCoordinator
var enemy_snapshot_accumulator: float = 0.0
var vehicle_snapshot_accumulator: float = 0.0
var wave_clock_accumulator: float = 0.0
var warmup_elapsed: float = 0.0
var remote_sync_ready: bool = false
var initialized: bool = false


func setup(run: RunCoordinator) -> void:
	coordinator = run
	coordinator.enemy_director.enemy_removed.connect(_on_enemy_removed)
	NetworkSession.session_failed.connect(_on_session_failed)
	remote_sync_ready = NetworkSession.role == NetworkSession.SessionRole.SOLO
	initialized = true
	if NetworkSession.is_host_authority(): broadcast_run_state()


func _physics_process(delta: float) -> void:
	if not initialized or not NetworkSession.is_host_authority(): return
	warmup_elapsed += delta
	if not remote_sync_ready and warmup_elapsed >= 0.5:
		remote_sync_ready = true
		broadcast_run_state()
	if not remote_sync_ready: return
	enemy_snapshot_accumulator += delta
	vehicle_snapshot_accumulator += delta
	wave_clock_accumulator += delta
	if enemy_snapshot_accumulator >= ENEMY_SNAPSHOT_INTERVAL:
		enemy_snapshot_accumulator -= ENEMY_SNAPSHOT_INTERVAL
		_send_enemy_snapshots()
	if vehicle_snapshot_accumulator >= VEHICLE_SNAPSHOT_INTERVAL:
		vehicle_snapshot_accumulator -= VEHICLE_SNAPSHOT_INTERVAL
		_send_vehicle_snapshot()
	if wave_clock_accumulator >= WAVE_CLOCK_INTERVAL:
		wave_clock_accumulator -= WAVE_CLOCK_INTERVAL
		_receive_wave_clock.rpc(coordinator.stage_director.wave_index, coordinator.stage_director.state_time)


func _send_enemy_snapshots() -> void:
	for child: Node in coordinator.enemy_director.get_children():
		var enemy := child as EnemyUnit
		if enemy != null and not enemy.is_network_replica:
			_receive_enemy_snapshot.rpc(enemy.net_id, String(enemy.enemy_type), enemy.side, enemy.position, enemy.hp, enemy.inside_vehicle, enemy.invasion_state, enemy.entry_time)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_enemy_snapshot(enemy_net_id: int, enemy_id: String, side: int, position_value: Vector2, hp: float, inside_vehicle: bool, invasion_state: int, entry_time: float) -> void:
	if NetworkSession.is_host_authority(): return
	var enemy: EnemyUnit = coordinator.enemy_director.spawn_network_replica(enemy_net_id, StringName(enemy_id), side)
	enemy.apply_network_snapshot(position_value, hp, inside_vehicle, invasion_state, entry_time)
	enemy_snapshot_received.emit()
	enemy_invasion_snapshot_received.emit(enemy_net_id, inside_vehicle, invasion_state)


func _on_enemy_removed(enemy_net_id: int) -> void:
	if NetworkSession.is_host_authority(): _remove_enemy.rpc(enemy_net_id)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _remove_enemy(enemy_net_id: int) -> void:
	coordinator.enemy_director.remove_network_replica(enemy_net_id)


func _send_vehicle_snapshot() -> void:
	var vehicle: VehicleState = coordinator.vehicle_state
	_receive_vehicle_snapshot.rpc(
		vehicle.hull, float(vehicle.section_hp[&"front"]), float(vehicle.section_hp[&"rear"]),
		float(vehicle.section_hp[&"roof"]), float(vehicle.section_hp[&"lower"]), vehicle.supplies,
		vehicle.is_breached(&"front"), vehicle.is_breached(&"rear"),
		vehicle.is_breached(&"roof"), vehicle.is_breached(&"lower"),
		coordinator.reward_system.kills
	)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_vehicle_snapshot(hull: float, front: float, rear: float, roof: float, lower: float, supplies: float, front_breach: bool, rear_breach: bool, roof_breach: bool, lower_breach: bool, kills: int) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.vehicle_state.apply_network_snapshot(hull, front, rear, roof, lower, supplies, front_breach, rear_breach, roof_breach, lower_breach)
		coordinator.reward_system.kills = kills
		vehicle_snapshot_received.emit(front)
		breach_snapshot_received.emit(front_breach, rear_breach, roof_breach, lower_breach)


func broadcast_run_state() -> void:
	if NetworkSession.is_host_authority() and remote_sync_ready:
		_receive_run_state.rpc(coordinator.stage_director.state, coordinator.stage_director.wave_index, coordinator.stage_director.state_time)


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
	if choices.size() == 3: _receive_reward_choices.rpc(String(choices[0].id), String(choices[1].id), String(choices[2].id))


@rpc("authority", "call_remote", "reliable", 0)
func _receive_reward_choices(first_id: String, second_id: String, third_id: String) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.receive_reward_choices(first_id, second_id, third_id)
		reward_choices_received.emit(StringName(first_id), StringName(second_id), StringName(third_id))


func broadcast_relic_selected(relic_id: StringName) -> void:
	_receive_relic_selected.rpc(String(relic_id))


@rpc("authority", "call_remote", "reliable", 0)
func _receive_relic_selected(relic_id: String) -> void:
	if not NetworkSession.is_host_authority():
		coordinator.receive_relic_selected(StringName(relic_id))
		relic_selected_received.emit(StringName(relic_id))


func broadcast_route_choices(choices: Array[RouteNodeDefinition]) -> void:
	if choices.size() == 2:
		_receive_route_choices.rpc(String(choices[0].id), String(choices[1].id))


@rpc("authority", "call_remote", "reliable", 0)
func _receive_route_choices(first_id: String, second_id: String) -> void:
	if NetworkSession.is_host_authority():
		return
	coordinator.receive_route_choices(first_id, second_id)
	route_choices_received.emit(StringName(first_id), StringName(second_id))


func broadcast_route_selected(route_id: StringName) -> void:
	_receive_route_selected.rpc(String(route_id))


@rpc("authority", "call_remote", "reliable", 0)
func _receive_route_selected(route_id: String) -> void:
	if NetworkSession.is_host_authority():
		return
	coordinator.receive_route_selected(StringName(route_id))
	route_selected_received.emit(StringName(route_id))


func broadcast_route_reward() -> void:
	_receive_route_reward.rpc(coordinator.module_system.scrap, coordinator.vehicle_state.supplies)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_route_reward(scrap: int, supplies: float) -> void:
	if NetworkSession.is_host_authority():
		return
	coordinator.module_system.scrap = scrap
	coordinator.vehicle_state.supplies = supplies
	route_reward_received.emit()


func broadcast_result(victory: bool) -> void:
	var relic_ids: Array[String] = ["", "", ""]
	for index: int in mini(3, coordinator.reward_system.acquired.size()): relic_ids[index] = String(coordinator.reward_system.acquired[index].id)
	_receive_result.rpc(victory, coordinator.reward_system.kills, relic_ids[0], relic_ids[1], relic_ids[2])


@rpc("authority", "call_remote", "reliable", 0)
func _receive_result(victory: bool, kills: int, first_relic_id: String, second_relic_id: String, third_relic_id: String) -> void:
	if not NetworkSession.is_host_authority(): coordinator.receive_result(victory, kills, first_relic_id, second_relic_id, third_relic_id)


func _on_session_failed(_message: String) -> void:
	set_physics_process(false)
