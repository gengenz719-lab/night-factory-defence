class_name GameDefinition
extends Resource

## すべてのゲーム定義Resourceが継承する共通基底。
## 実行中に変化するHPやスタック数は保持しない。

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
@export var icon: Texture2D
@export var tags: Array[StringName] = []
@export_range(1, 2147483647, 1) var content_version: int = 1


## 派生Resourceが別定義をID参照する場合に上書きする。
## GameCatalogは返された全IDが登録済みかを検査する。
func get_referenced_definition_ids() -> Array[StringName]:
	return []
