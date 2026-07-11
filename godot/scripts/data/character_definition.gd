class_name CharacterDefinition
extends GameDefinition

@export var max_hp: float = 100.0
@export var move_speed_cells_per_second: float = 3.8
@export var jump_height_cells: float = 1.7
@export var gravity_px: float = 1450.0
@export var dodge_distance_cells: float = 1.5
@export var dodge_invulnerability_seconds: float = 0.2
@export var dodge_cooldown_seconds: float = 1.4
@export var melee_damage: float = 10.0
@export var melee_cooldown_seconds: float = 0.8
@export var revive_seconds: float = 3.0
@export var downed_grace_seconds: float = 20.0
@export var return_wait_seconds: float = 8.0
@export var critical_chance: float = 0.05
@export var repair_speed_multiplier: float = 1.0
@export var operation_speed_multiplier: float = 1.0
@export var starting_weapon_id: StringName = &""
@export var damage_invulnerability_seconds: float = 0.7
@export var respawn_health_ratio: float = 0.5
@export var repair_tap_seconds: float = 0.25
@export var tap_move_step_px: float = 12.0
@export var climb_horizontal_speed_px: float = 300.0
@export var climb_vertical_speed_px: float = 245.0

func get_referenced_definition_ids() -> Array[StringName]:
	return [starting_weapon_id]
