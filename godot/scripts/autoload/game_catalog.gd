extends Node

## 明示マニフェストからゲーム定義を読み込み、安定IDで検索できるようにする。
## パス列挙はエクスポート後もResourceLoaderのremap解決を通る。

const DEFINITION_PATHS: PackedStringArray = [
	"res://data/characters/character_survivor.tres",
	"res://data/enemies/enemy_walker.tres",
	"res://data/enemies/enemy_runner.tres",
	"res://data/enemies/enemy_climber.tres",
	"res://data/modules/vehicle_survival.tres",
	"res://data/relics/relic_heavy_rounds.tres",
	"res://data/relics/relic_plating.tres",
	"res://data/relics/relic_comfort.tres",
	"res://data/stages/wave_01.tres",
	"res://data/stages/wave_02.tres",
	"res://data/weapons/weapon_rifle.tres",
]

var _definitions: Dictionary[StringName, GameDefinition] = {}


func _ready() -> void:
	var errors: PackedStringArray = reload_catalog()
	for message: String in errors:
		push_error("GameCatalog: %s" % message)


func reload_catalog() -> PackedStringArray:
	_definitions.clear()
	var load_errors := PackedStringArray()
	var definitions: Array[GameDefinition] = []
	for resource_path: String in DEFINITION_PATHS:
		var loaded: Resource = ResourceLoader.load(resource_path)
		if loaded == null:
			load_errors.append("読み込み不能: %s" % resource_path)
			continue
		if loaded is not GameDefinition:
			load_errors.append("GameDefinition未継承: %s" % resource_path)
			continue
		definitions.append(loaded as GameDefinition)

	var validation_errors: PackedStringArray = validate_definitions(definitions)
	load_errors.append_array(validation_errors)
	load_errors.append_array(_validate_category_coverage(definitions))
	if load_errors.is_empty():
		for definition: GameDefinition in definitions:
			_definitions[definition.id] = definition
	return load_errors


func validate_definitions(definitions: Array[GameDefinition]) -> PackedStringArray:
	var errors := PackedStringArray()
	var definitions_by_id: Dictionary[StringName, GameDefinition] = {}

	for definition: GameDefinition in definitions:
		if definition == null:
			errors.append("無効なResource参照")
			continue
		if definition.id.is_empty():
			errors.append("空ID: %s" % definition.resource_path)
			continue
		if definitions_by_id.has(definition.id):
			errors.append("ID重複: %s" % definition.id)
			continue
		definitions_by_id[definition.id] = definition

	for definition: GameDefinition in definitions:
		if definition == null or definition.id.is_empty():
			continue
		for referenced_id: StringName in definition.get_referenced_definition_ids():
			if referenced_id.is_empty() or not definitions_by_id.has(referenced_id):
				errors.append("無効参照: %s -> %s" % [definition.id, referenced_id])
		if definition is WaveDefinition:
			var wave := definition as WaveDefinition
			if wave.enemy_ids.size() != wave.enemy_weights.size() or wave.enemy_ids.is_empty():
				errors.append("Wave編成不正: %s" % wave.id)
			var total_weight: float = 0.0
			for weight: float in wave.enemy_weights:
				total_weight += weight
			if not is_equal_approx(total_weight, 1.0):
				errors.append("Wave比率不正: %s = %.3f" % [wave.id, total_weight])
	return errors


func get_definition(definition_id: StringName) -> GameDefinition:
	return _definitions.get(definition_id) as GameDefinition


func has_definition(definition_id: StringName) -> bool:
	return _definitions.has(definition_id)


func get_all_definitions() -> Array[GameDefinition]:
	var result: Array[GameDefinition] = []
	for definition: GameDefinition in _definitions.values():
		result.append(definition)
	return result


func get_definitions_with_tag(tag: StringName) -> Array[GameDefinition]:
	var result: Array[GameDefinition] = []
	for definition: GameDefinition in _definitions.values():
		if definition.tags.has(tag):
			result.append(definition)
	return result


func _validate_category_coverage(definitions: Array[GameDefinition]) -> PackedStringArray:
	var errors := PackedStringArray()
	var counts: Dictionary[StringName, int] = {
		&"character": 0, &"enemy": 0, &"vehicle": 0,
		&"relic": 0, &"wave": 0, &"weapon": 0,
	}
	for definition: GameDefinition in definitions:
		if definition is CharacterDefinition: counts[&"character"] += 1
		elif definition is EnemyDefinition: counts[&"enemy"] += 1
		elif definition is VehicleDefinition: counts[&"vehicle"] += 1
		elif definition is RelicDefinition: counts[&"relic"] += 1
		elif definition is WaveDefinition: counts[&"wave"] += 1
		elif definition is WeaponDefinition: counts[&"weapon"] += 1
	for category: StringName in counts:
		if counts[category] <= 0:
			errors.append("カテゴリ未登録: %s" % category)
	return errors
