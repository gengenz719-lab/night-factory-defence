class_name RouteNodeDefinition
extends GameDefinition

## 最小スライス用のルートノード定義。将来の10列DAGでも同じ定義を再利用する。

@export var fallback_display_name: String = ""
@export_multiline var fallback_description: String = ""
@export var node_type: StringName = &"road"
@export var threat_label: String = "標準"
@export var primary_enemy_id: StringName = &""
@export var danger_text: String = "なし"
@export var reward_text: String = "標準"
@export var enemy_budget_multiplier: float = 1.0
@export var preferred_enemy_weight_multiplier: float = 1.0
@export var scrap_reward: int = 0
@export var supply_reward: float = 0.0


func get_referenced_definition_ids() -> Array[StringName]:
	return [primary_enemy_id] if not primary_enemy_id.is_empty() else []
