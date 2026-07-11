class_name RelicDefinition
extends GameDefinition

@export var fallback_display_name: String = ""
@export_multiline var fallback_description: String = ""
@export var category: StringName = &"special"
@export var rarity: StringName = &"common"
@export var max_stacks: int = 1
@export var choice_order: int = 0
@export var weapon_damage_multiplier: float = 1.0
@export var exterior_hp_multiplier: float = 1.0
@export var heal_exterior_increase: bool = false
@export var wave_end_player_heal: float = 0.0
@export var comfort_effect_multiplier: float = 1.0
