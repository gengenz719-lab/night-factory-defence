class_name VehicleModuleState
extends RefCounted

var instance_id: int = 0
var definition: ModuleDefinition
var grid_position: Vector2i = Vector2i.ZERO
var hp: float = 0.0
var priority: int = 2
var powered: bool = true
var heat: float = 0.0
var overheated: bool = false
var overheat_time: float = 0.0
var fire_cooldown: float = 0.0


func setup(id_value: int, module_definition: ModuleDefinition, position_value: Vector2i) -> void:
	instance_id = id_value
	definition = module_definition
	grid_position = position_value
	hp = definition.max_hp
	priority = definition.default_priority


func hp_ratio() -> float:
	return hp / maxf(1.0, definition.max_hp)


func is_operational() -> bool:
	return hp > 0.0 and powered
