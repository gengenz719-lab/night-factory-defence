class_name CatalogFixtureDefinition
extends GameDefinition

## GameCatalogの参照切れ検出をスモークテストする専用fixture。

var referenced_ids: Array[StringName] = []


func get_referenced_definition_ids() -> Array[StringName]:
	return referenced_ids
