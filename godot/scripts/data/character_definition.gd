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
@export var revive_interaction_range_px: float = 96.0
@export var revive_health_ratio: float = 0.35
@export var revive_invulnerability_seconds: float = 2.0
@export var revive_interrupt_grace_seconds: float = 0.15
@export var downed_grace_seconds: float = 20.0
@export var return_wait_seconds: float = 8.0
@export var return_health_ratio: float = 0.5
@export var critical_chance: float = 0.05
@export var role_name: String = "Survivor"
@export var weapon_damage_multiplier: float = 1.0
@export var repair_speed_multiplier: float = 1.0
@export var operation_speed_multiplier: float = 1.0
@export var starting_weapon_id: StringName = &""
@export var ability_id: StringName = &""
@export var ability_name: String = "Ability"
@export var ability_duration_seconds: float = 0.0
@export var ability_cooldown_seconds: float = 24.0
@export var ability_attack_speed_multiplier: float = 1.0
@export var ability_reload_speed_multiplier: float = 1.0
@export var ability_recoil_multiplier: float = 1.0
@export var ability_repair_hp_per_second: float = 0.0
@export var damage_invulnerability_seconds: float = 0.7
@export var repair_tap_seconds: float = 0.25
@export var tap_move_step_px: float = 12.0
@export var climb_horizontal_speed_px: float = 300.0
@export var climb_vertical_speed_px: float = 245.0

func get_referenced_definition_ids() -> Array[StringName]:
	return [starting_weapon_id]
