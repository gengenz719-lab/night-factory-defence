class_name ModuleDefinition
extends GameDefinition

@export var fallback_display_name: String = "Module"
@export var fallback_description: String = ""
@export_enum("interior", "side_exterior", "roof_exterior") var placement_zone: String = "interior"
@export var grid_size: Vector2i = Vector2i.ONE
@export var scrap_cost: int = 0
@export var max_hp: float = 100.0
@export var power_generation: int = 0
@export var power_consumption: int = 0
@export_range(1, 3, 1) var default_priority: int = 2
@export var blocks_passage: bool = false
@export var repair_speed_multiplier: float = 1.0
@export var repair_efficiency_multiplier: float = 1.0
@export var turret_damage: float = 0.0
@export var turret_shots_per_second: float = 0.0
@export var turret_range_cells: float = 0.0
@export var heat_per_shot: float = 0.0
@export var heat_limit: float = 100.0
@export var heat_cool_per_second: float = 0.0
@export var overheat_stop_seconds: float = 0.0
@export var overheat_recovery_heat: float = 0.0
