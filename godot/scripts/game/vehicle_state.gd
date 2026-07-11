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
	var target: StringName = _lowest_damaged_section()
	var heal_per_second: float = definition.repair_hp_per_second * repair_multiplier * player_multiplier
	var heal: float = heal_per_second * delta
	if target != &"":
		section_hp[target] = minf(float(max_section_hp[target]), float(section_hp[target]) + heal)
	elif hull < max_hull:
		hull = minf(max_hull, hull + heal * definition.hull_hp_per_supply / definition.exterior_hp_per_supply)
	else:
		return false
	_repair_supply_progress += heal / definition.exterior_hp_per_supply
	while _repair_supply_progress >= 1.0 and supplies >= 1.0:
		_repair_supply_progress -= 1.0
		supplies -= 1.0
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


func _lowest_damaged_section() -> StringName:
	var result: StringName = &""
	var lowest_ratio: float = 1.01
	for key: StringName in max_section_hp:
		var ratio: float = float(section_hp[key]) / float(max_section_hp[key])
		if ratio < 1.0 and ratio < lowest_ratio:
			lowest_ratio = ratio
			result = key
	return result
