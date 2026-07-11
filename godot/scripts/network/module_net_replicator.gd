class_name ModuleNetReplicator
extends Node

signal request_rejected(message: String)
signal module_state_received(instance_id: int, hp: float)

const SNAPSHOT_INTERVAL: float = 0.2

var coordinator: RunCoordinator
var module_system: VehicleModuleSystem
var snapshot_time: float = 0.0
var initialized: bool = false
var remote_place_intents_received: int = 0


func setup(run: RunCoordinator, system: VehicleModuleSystem) -> void:
	coordinator = run
	module_system = system
	initialized = true


func _physics_process(delta: float) -> void:
	if not initialized or not NetworkSession.is_host_authority():
		return
	module_system.authority_tick(delta)
	snapshot_time += delta
	if snapshot_time < SNAPSHOT_INTERVAL:
		return
	snapshot_time -= SNAPSHOT_INTERVAL
	for module: VehicleModuleState in module_system.modules.values():
		_receive_module_state.rpc(module.instance_id, module.hp, module.powered, module.heat, module.overheated)


func request_place(module_id: StringName, position: Vector2i) -> void:
	if NetworkSession.is_host_authority():
		_authority_place(NetworkSession.local_peer_id(), module_id, position)
	else:
		_submit_place.rpc_id(NetworkSession.HOST_PEER_ID, String(module_id), position.x, position.y)


func request_priority(instance_id: int, priority_value: int) -> void:
	if NetworkSession.is_host_authority():
		_authority_priority(instance_id, priority_value)
	else:
		_submit_priority.rpc_id(NetworkSession.HOST_PEER_ID, instance_id, priority_value)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_place(module_id: String, x_value: int, y_value: int) -> void:
	if not NetworkSession.is_host_authority():
		return
	remote_place_intents_received += 1
	_authority_place(multiplayer.get_remote_sender_id(), StringName(module_id), Vector2i(x_value, y_value))


func _authority_place(requester_peer_id: int, module_id: StringName, position: Vector2i) -> void:
	var instance_id: int = module_system.request_place(module_id, position)
	if instance_id <= 0:
		if requester_peer_id != NetworkSession.local_peer_id():
			_receive_rejection.rpc_id(requester_peer_id, "配置条件を満たしていません")
		return
	var module: VehicleModuleState = module_system.modules[instance_id]
	_confirm_place.rpc(instance_id, String(module_id), position.x, position.y, module.priority, module_system.scrap)


@rpc("authority", "call_remote", "reliable", 0)
func _confirm_place(instance_id: int, module_id: String, x_value: int, y_value: int, priority_value: int, remaining_scrap: int) -> void:
	if NetworkSession.is_host_authority():
		return
	var module: VehicleModuleState = module_system.place_confirmed(instance_id, StringName(module_id), Vector2i(x_value, y_value), false)
	if module != null:
		module.priority = priority_value
	module_system.scrap = remaining_scrap
	module_system.recalculate_power()


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_priority(instance_id: int, priority_value: int) -> void:
	if NetworkSession.is_host_authority():
		_authority_priority(instance_id, priority_value)


func _authority_priority(instance_id: int, priority_value: int) -> void:
	if module_system.set_priority(instance_id, priority_value):
		_confirm_priority.rpc(instance_id, clampi(priority_value, 1, 3))


@rpc("authority", "call_remote", "reliable", 0)
func _confirm_priority(instance_id: int, priority_value: int) -> void:
	if not NetworkSession.is_host_authority():
		module_system.apply_priority_confirmed(instance_id, priority_value)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_module_state(instance_id: int, hp_value: float, powered_value: bool, heat_value: float, overheated_value: bool) -> void:
	if not NetworkSession.is_host_authority():
		module_system.apply_state(instance_id, hp_value, powered_value, heat_value, overheated_value)
		module_state_received.emit(instance_id, hp_value)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_rejection(message: String) -> void:
	request_rejected.emit(message)
