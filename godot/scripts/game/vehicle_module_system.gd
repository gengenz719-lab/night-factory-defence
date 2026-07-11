class_name VehicleModuleSystem
extends Node

signal layout_changed
signal values_changed
signal placement_rejected(message: String)
signal module_placed(module: VehicleModuleState)
signal priority_changed(module: VehicleModuleState)
signal turret_fired(instance_id: int)

const CELL_SIZE_PX: float = 64.0
const GRID_ORIGIN: Vector2 = Vector2(544.0, 278.0)

var vehicle_definition: VehicleDefinition
var enemy_director: EnemyDirector
var modules: Dictionary[int, VehicleModuleState] = {}
var scrap: int = 0
var power_generated: int = 0
var power_requested: int = 0
var power_consumed: int = 0
var next_instance_id: int = 1
var can_edit: bool = true
var combat_active: bool = false
var turret_shots: int = 0


func setup(definition: VehicleDefinition, enemies: EnemyDirector) -> void:
	vehicle_definition = definition
	enemy_director = enemies
	scrap = definition.initial_scrap
	modules.clear()
	next_instance_id = 1
	for index: int in mini(definition.initial_module_ids.size(), definition.initial_module_positions.size()):
		place_confirmed(next_instance_id, definition.initial_module_ids[index], definition.initial_module_positions[index], false)
	recalculate_power()


func request_place(module_id: StringName, position: Vector2i) -> int:
	if not can_edit:
		return _reject("モジュール配置は準備中のみ可能です")
	var definition := GameCatalog.get_definition(module_id) as ModuleDefinition
	if definition == null:
		return _reject("不明なモジュールです")
	var reason: String = validate_placement(definition, position)
	if not reason.is_empty():
		return _reject(reason)
	if scrap < definition.scrap_cost:
		return _reject("スクラップが不足しています")
	var instance_id: int = next_instance_id
	place_confirmed(instance_id, module_id, position, true)
	return instance_id


func place_confirmed(instance_id: int, module_id: StringName, position: Vector2i, charge_cost: bool) -> VehicleModuleState:
	if modules.has(instance_id):
		return modules[instance_id]
	var definition := GameCatalog.get_definition(module_id) as ModuleDefinition
	if definition == null:
		return null
	var module := VehicleModuleState.new()
	module.setup(instance_id, definition, position)
	modules[instance_id] = module
	next_instance_id = maxi(next_instance_id, instance_id + 1)
	if charge_cost:
		scrap = maxi(0, scrap - definition.scrap_cost)
	recalculate_power()
	layout_changed.emit()
	module_placed.emit(module)
	return module


func validate_placement(definition: ModuleDefinition, position: Vector2i) -> String:
	var size: Vector2i = definition.grid_size
	if position.x < 0 or position.y < 0 or position.x + size.x > vehicle_definition.grid_width or position.y + size.y > vehicle_definition.grid_height:
		return "車両グリッドの外には配置できません"
	if not _zone_is_valid(definition, position):
		return "このモジュール種別を置けない区画です"
	for y_value: int in range(position.y, position.y + size.y):
		for x_value: int in range(position.x, position.x + size.x):
			var cell := Vector2i(x_value, y_value)
			if cell in [Vector2i(0, 2), Vector2i(1, 2)]:
				return "操縦席コアは塞げません"
			if cell in [Vector2i(vehicle_definition.ladder_column, 1), Vector2i(vehicle_definition.ladder_column, 2)]:
				return "はしごの上下1セルは塞げません"
			if module_at_cell(cell) != null:
				return "すでに別のモジュールがあります"
	if position.y in [1, 2] and not _leaves_passage_cell(position, size):
		return "左右をつなぐ通路を完全に塞げません"
	if definition.blocks_passage and not _has_left_right_route(position, size):
		return "左右をつなぐ通路を完全に塞げません"
	return ""


func set_priority(instance_id: int, priority_value: int) -> bool:
	var module: VehicleModuleState = modules.get(instance_id) as VehicleModuleState
	if module == null:
		return false
	module.priority = clampi(priority_value, 1, 3)
	recalculate_power()
	priority_changed.emit(module)
	return true


func apply_priority_confirmed(instance_id: int, priority_value: int) -> void:
	var module: VehicleModuleState = modules.get(instance_id) as VehicleModuleState
	if module != null:
		module.priority = clampi(priority_value, 1, 3)
		recalculate_power()


func recalculate_power() -> void:
	power_generated = 0
	power_requested = 0
	power_consumed = 0
	var consumers: Array[VehicleModuleState] = []
	for module: VehicleModuleState in modules.values():
		module.powered = module.hp > 0.0
		if module.hp <= 0.0:
			continue
		power_generated += module.definition.power_generation
		power_requested += module.definition.power_consumption
		if module.definition.power_consumption > 0:
			consumers.append(module)
	consumers.sort_custom(func(a: VehicleModuleState, b: VehicleModuleState) -> bool:
		if a.priority != b.priority: return a.priority > b.priority
		return a.instance_id < b.instance_id
	)
	for module: VehicleModuleState in consumers:
		var demand: int = module.definition.power_consumption
		module.powered = power_consumed + demand <= power_generated
		if module.powered:
			power_consumed += demand
	values_changed.emit()


func authority_tick(delta: float) -> void:
	for module: VehicleModuleState in modules.values():
		if module.definition.id == &"module_turret":
			_tick_turret(module, delta)


func active_workbench() -> VehicleModuleState:
	var module: VehicleModuleState = workbench_module()
	return module if module != null and module.is_operational() else null


func workbench_module() -> VehicleModuleState:
	for module: VehicleModuleState in modules.values():
		if module.definition.id == &"module_workbench":
			return module
	return null


func lowest_damaged_module(cap_ratio: float) -> VehicleModuleState:
	var result: VehicleModuleState
	var lowest_ratio: float = cap_ratio
	for module: VehicleModuleState in modules.values():
		var ratio: float = module.hp_ratio()
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			result = module
	return result


func repair_module(module: VehicleModuleState, amount: float, cap_ratio: float) -> float:
	if module == null:
		return 0.0
	var cap: float = module.definition.max_hp * cap_ratio
	var restored: float = minf(amount, maxf(0.0, cap - module.hp))
	module.hp += restored
	recalculate_power()
	return restored


func module_at_cell(cell: Vector2i) -> VehicleModuleState:
	for module: VehicleModuleState in modules.values():
		var rect := Rect2i(module.grid_position, module.definition.grid_size)
		if rect.has_point(cell):
			return module
	return null


func grid_to_world(position: Vector2i, size: Vector2i = Vector2i.ONE) -> Vector2:
	return GRID_ORIGIN + (Vector2(position) + Vector2(size) * 0.5) * CELL_SIZE_PX


func apply_state(instance_id: int, hp_value: float, powered_value: bool, heat_value: float, overheated_value: bool) -> void:
	var module: VehicleModuleState = modules.get(instance_id) as VehicleModuleState
	if module == null:
		return
	module.hp = clampf(hp_value, 0.0, module.definition.max_hp)
	module.powered = powered_value
	module.heat = maxf(0.0, heat_value)
	module.overheated = overheated_value
	values_changed.emit()


func _tick_turret(module: VehicleModuleState, delta: float) -> void:
	var definition: ModuleDefinition = module.definition
	module.fire_cooldown = maxf(0.0, module.fire_cooldown - delta)
	module.heat = maxf(0.0, module.heat - definition.heat_cool_per_second * delta)
	if module.overheated:
		module.overheat_time = maxf(0.0, module.overheat_time - delta)
		if module.overheat_time <= 0.0 and module.heat <= definition.overheat_recovery_heat:
			module.overheated = false
		return
	if not combat_active or not module.is_operational() or module.fire_cooldown > 0.0:
		return
	var target: EnemyUnit = _nearest_enemy(module)
	if target == null:
		return
	target.take_damage(definition.turret_damage)
	module.fire_cooldown = 1.0 / definition.turret_shots_per_second
	module.heat += definition.heat_per_shot
	turret_shots += 1
	turret_fired.emit(module.instance_id)
	if module.heat >= definition.heat_limit:
		module.heat = definition.heat_limit
		module.overheated = true
		module.overheat_time = definition.overheat_stop_seconds
	values_changed.emit()


func _nearest_enemy(module: VehicleModuleState) -> EnemyUnit:
	if enemy_director == null:
		return null
	var origin: Vector2 = grid_to_world(module.grid_position, module.definition.grid_size)
	var max_distance: float = module.definition.turret_range_cells * CELL_SIZE_PX
	var result: EnemyUnit
	var closest: float = max_distance
	for child: Node in enemy_director.get_children():
		var enemy := child as EnemyUnit
		if enemy != null and not enemy.is_network_replica:
			var distance: float = origin.distance_to(enemy.position)
			if distance <= closest:
				closest = distance
				result = enemy
	return result


func _zone_is_valid(definition: ModuleDefinition, position: Vector2i) -> bool:
	match definition.placement_zone:
		"interior": return position.y in [1, 2]
		"side_exterior": return position.y == 1
		"roof_exterior": return position.y in [0, vehicle_definition.grid_height - 1]
	return false


func _has_left_right_route(candidate_position: Vector2i, candidate_size: Vector2i) -> bool:
	for row: int in [1, 2]:
		var clear: bool = true
		for x_value: int in vehicle_definition.grid_width:
			var cell := Vector2i(x_value, row)
			if Rect2i(candidate_position, candidate_size).has_point(cell):
				clear = false
				break
			var existing: VehicleModuleState = module_at_cell(cell)
			if existing != null and existing.definition.blocks_passage:
				clear = false
				break
		if clear:
			return true
	return false


func _leaves_passage_cell(candidate_position: Vector2i, candidate_size: Vector2i) -> bool:
	var row: int = candidate_position.y
	var occupied: Dictionary[Vector2i, bool] = {}
	occupied[Vector2i(vehicle_definition.ladder_column, row)] = true
	if row == 2:
		occupied[Vector2i(0, row)] = true
		occupied[Vector2i(1, row)] = true
	for module: VehicleModuleState in modules.values():
		if module.grid_position.y != row:
			continue
		for x_value: int in range(module.grid_position.x, module.grid_position.x + module.definition.grid_size.x):
			occupied[Vector2i(x_value, row)] = true
	for x_value: int in range(candidate_position.x, candidate_position.x + candidate_size.x):
		occupied[Vector2i(x_value, row)] = true
	return occupied.size() < vehicle_definition.grid_width


func _reject(message: String) -> int:
	placement_rejected.emit(message)
	return 0
