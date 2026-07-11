class_name VehicleState
extends Node

signal destroyed
signal values_changed

@onready var visual: SurvivalVehicle = $Vehicle as SurvivalVehicle

var definition: VehicleDefinition
var max_hull: float = 0.0
var hull: float = 0.0
var max_section_hp: Dictionary = {}
var section_hp: Dictionary = {}
var supplies: float = 0.0
var repair_multiplier: float = 1.0
var module_system: VehicleModuleSystem
var combat_active: bool = false
var _repair_supply_progress: float = 0.0


func setup(vehicle_data: VehicleDefinition) -> void:
	definition = vehicle_data
	max_hull = definition.hull_hp
	hull = max_hull
	max_section_hp = {
		&"front": definition.front_armor_hp,
		&"rear": definition.rear_armor_hp,
		&"roof": definition.roof_armor_hp,
		&"lower": definition.lower_armor_hp,
	}
	section_hp = max_section_hp.duplicate()
	supplies = definition.initial_supplies
	visual.setup(self)


func floor_y(level: int) -> float:
	return visual.floor_y(level)


func is_breached(section: StringName) -> bool:
	return float(section_hp.get(section, 0.0)) <= 0.0


func take_attack(section: StringName, amount: float) -> void:
	if hull <= 0.0:
		return
	var remaining: float = amount
	var current_section: float = float(section_hp.get(section, 0.0))
	if current_section > 0.0:
		var absorbed: float = minf(current_section, remaining)
		section_hp[section] = current_section - absorbed
		remaining -= absorbed
	if remaining > 0.0:
		hull = maxf(0.0, hull - remaining)
	visual.flash_damage()
	values_changed.emit()
	if hull <= 0.0:
		destroyed.emit()


func repair_at(player_position: Vector2, delta: float, player_multiplier: float) -> bool:
	if player_position.distance_to(SurvivalVehicle.REPAIR_CONSOLE) > definition.repair_interaction_range_px or supplies < 1.0:
		return false
	var workbench: VehicleModuleState = module_system.workbench_module() if module_system != null else null
	if workbench == null:
		return false
	var workbench_operational: bool = workbench.is_operational()
	var cap_ratio: float = definition.combat_repair_cap_ratio if combat_active else 1.0
	var target_module: VehicleModuleState = module_system.lowest_damaged_module(cap_ratio)
	var target: StringName = _lowest_damaged_section(cap_ratio)
	var section_ratio_value: float = section_ratio(target) if target != &"" else cap_ratio
	if target_module != null and target_module.hp_ratio() <= section_ratio_value:
		target = &""
	var speed_bonus: float = workbench.definition.repair_speed_multiplier if workbench_operational else 1.0
	var heal_per_second: float = definition.repair_hp_per_second * repair_multiplier * player_multiplier * speed_bonus
	var heal: float = heal_per_second * delta
	var restored: float = 0.0
	var hp_per_supply: float = definition.exterior_hp_per_supply
	if target_module != null and target == &"":
		restored = module_system.repair_module(target_module, heal, cap_ratio)
		hp_per_supply = definition.module_hp_per_supply
	elif target != &"":
		var cap: float = float(max_section_hp[target]) * cap_ratio
		restored = minf(heal, maxf(0.0, cap - float(section_hp[target])))
		section_hp[target] = float(section_hp[target]) + restored
	elif hull < max_hull * cap_ratio:
		restored = minf(heal, max_hull * cap_ratio - hull)
		hull += restored
		hp_per_supply = definition.hull_hp_per_supply
	else:
		return false
	var efficiency: float = workbench.definition.repair_efficiency_multiplier if workbench_operational and not combat_active else 1.0
	_repair_supply_progress += restored / (hp_per_supply * efficiency)
	while _repair_supply_progress >= 1.0 and supplies >= 1.0:
		_repair_supply_progress -= 1.0
		supplies -= 1.0
	values_changed.emit()
	return true


func repair_without_supplies(amount: float) -> bool:
	var cap_ratio: float = definition.combat_repair_cap_ratio if combat_active else 1.0
	var target_module: VehicleModuleState = module_system.lowest_damaged_module(cap_ratio) if module_system != null else null
	var target: StringName = _lowest_damaged_section(cap_ratio)
	var section_ratio_value: float = section_ratio(target) if target != &"" else cap_ratio
	if target_module != null and target_module.hp_ratio() <= section_ratio_value:
		module_system.repair_module(target_module, amount, cap_ratio)
	elif target != &"":
		section_hp[target] = minf(float(max_section_hp[target]) * cap_ratio, float(section_hp[target]) + amount)
	elif hull < max_hull * cap_ratio:
		hull = minf(max_hull * cap_ratio, hull + amount)
	else:
		return false
	values_changed.emit()
	return true


func apply_relic(relic: RelicDefinition) -> void:
	for key: StringName in max_section_hp:
		var old_max: float = float(max_section_hp[key])
		max_section_hp[key] = old_max * relic.exterior_hp_multiplier
		if relic.heal_exterior_increase:
			section_hp[key] = minf(float(max_section_hp[key]), float(section_hp[key]) + float(max_section_hp[key]) - old_max)
	values_changed.emit()


func section_ratio(section: StringName) -> float:
	return float(section_hp.get(section, 0.0)) / float(max_section_hp.get(section, 1.0))


func apply_network_snapshot(
	authoritative_hull: float,
	front_hp: float,
	rear_hp: float,
	roof_hp: float,
	lower_hp: float,
	authoritative_supplies: float
) -> void:
	hull = clampf(authoritative_hull, 0.0, max_hull)
	section_hp[&"front"] = clampf(front_hp, 0.0, float(max_section_hp[&"front"]))
	section_hp[&"rear"] = clampf(rear_hp, 0.0, float(max_section_hp[&"rear"]))
	section_hp[&"roof"] = clampf(roof_hp, 0.0, float(max_section_hp[&"roof"]))
	section_hp[&"lower"] = clampf(lower_hp, 0.0, float(max_section_hp[&"lower"]))
	supplies = maxf(0.0, authoritative_supplies)
	values_changed.emit()


func _lowest_damaged_section(cap_ratio: float = 1.0) -> StringName:
	var result: StringName = &""
	var lowest_ratio: float = cap_ratio
	for key: StringName in max_section_hp:
		var ratio: float = float(section_hp[key]) / float(max_section_hp[key])
		if ratio < 1.0 and ratio < lowest_ratio:
			lowest_ratio = ratio
			result = key
	return result
