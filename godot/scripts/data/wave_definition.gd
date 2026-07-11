class_name WaveDefinition
extends GameDefinition

@export var wave_number: int = 1
@export var duration_seconds: float = 90.0
@export var threat_budget: int = 1
@export var enemy_ids: Array[StringName] = []
@export var enemy_weights: Array[float] = []
@export var spawn_interval_seconds: float = 1.0
@export var max_alive_enemies: int = 32
@export var first_front_only_seconds: float = 0.0
@export var prepare_duration_seconds: float = 10.0
@export var first_spawn_delay_seconds: float = 0.2
@export var front_spawn_chance: float = 0.48
@export var intro_end_ratio: float = 0.2
@export var main_force_end_ratio: float = 0.75
@export var intro_budget_ratio: float = 0.15
@export var main_force_budget_ratio: float = 0.55
@export var rush_budget_ratio: float = 0.3
@export var pre_rush_respite_seconds: float = 8.0
@export var budget_carry_seconds: float = 20.0

func get_referenced_definition_ids() -> Array[StringName]:
	return enemy_ids
