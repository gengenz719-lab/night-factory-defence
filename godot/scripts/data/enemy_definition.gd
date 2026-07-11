class_name EnemyDefinition
extends GameDefinition

@export var unlock_wave: int = 1
@export var threat_cost: int = 1
@export var max_hp: float = 1.0
@export var speed_cells_per_second: float = 1.0
@export var player_damage: float = 1.0
@export var exterior_dps: float = 1.0
@export var stagger_resistance: float = 1.0
@export var path_type: StringName = &"ground"
@export var attack_interval_seconds: float = 0.75
@export var interior_vehicle_damage_ratio: float = 0.12
@export var interior_attack_range_px: float = 44.0
@export var exterior_attack_range_px: float = 18.0
@export var can_invade: bool = false
@export var breach_entry_seconds: float = 0.6
@export var interior_target_range_cells: float = 2.5
@export var target_reevaluation_seconds: float = 0.25
