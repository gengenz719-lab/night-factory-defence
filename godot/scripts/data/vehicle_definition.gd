class_name VehicleDefinition
extends GameDefinition

@export var hull_hp: float = 1000.0
@export var front_armor_hp: float = 300.0
@export var rear_armor_hp: float = 250.0
@export var roof_armor_hp: float = 220.0
@export var lower_armor_hp: float = 220.0
@export var initial_power: int = 6
@export var initial_scrap: int = 160
@export var initial_supplies: float = 100.0
@export var initial_fuel: int = 3
@export var scrap_cap: int = 9999
@export var supplies_cap: int = 200
@export var fuel_cap: int = 9
@export var repair_hp_per_second: float = 20.0
@export var hull_hp_per_supply: float = 8.0
@export var exterior_hp_per_supply: float = 10.0
@export var module_hp_per_supply: float = 12.0
@export var combat_repair_cap_ratio: float = 0.6
@export var breach_seal_supply_cost: int = 8
@export var breach_warning_ratio: float = 0.25
@export var repair_interaction_range_px: float = 95.0
@export var additional_repairer_efficiency: Array[float] = [0.6, 0.3, 0.15]
@export var grid_width: int = 8
@export var grid_height: int = 4
@export var ladder_column: int = 5
@export var initial_module_ids: Array[StringName] = []
@export var initial_module_positions: Array[Vector2i] = []


func get_referenced_definition_ids() -> Array[StringName]:
	return initial_module_ids
