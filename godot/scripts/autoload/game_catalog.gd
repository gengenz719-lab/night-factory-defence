extends Node

## res://data以下のゲーム定義を読み込み、安定IDで検索できるようにする。

const DATA_ROOT: String = "res://data"

var _definitions: Dictionary[StringName, GameDefinition] = {}


func _ready() -> void:
	var errors: PackedStringArray = reload_catalog()
	for message: String in errors:
		push_error("GameCatalog: %s" % message)


func reload_catalog() -> PackedStringArray:
	_definitions.clear()
	var load_errors := PackedStringArray()
	var definitions: Array[GameDefinition] = []
	for resource_path: String in _collect_resource_paths(DATA_ROOT):
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


func _collect_resource_paths(directory_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path: String = directory_path.path_join(entry_name)
			if directory.current_is_dir():
				result.append_array(_collect_resource_paths(entry_path))
			elif entry_name.get_extension().to_lower() == "tres":
				result.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result
