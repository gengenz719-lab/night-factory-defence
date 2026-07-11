class_name RouteGenerator
extends RefCounted

## シード付きrouteストリームから、次列の候補を重複なしで生成する。
## 現在は2列骨組みだが、候補プールを増やせばDAG生成へ拡張できる。

var _random: RandomNumberGenerator
var _pool: Array[RouteNodeDefinition] = []


func setup(random_stream: RandomNumberGenerator, route_pool: Array[RouteNodeDefinition]) -> void:
	_random = random_stream
	_pool = route_pool.duplicate()


func generate_choices(choice_count: int) -> Array[RouteNodeDefinition]:
	var available: Array[RouteNodeDefinition] = _pool.duplicate()
	var choices: Array[RouteNodeDefinition] = []
	while not available.is_empty() and choices.size() < choice_count:
		choices.append(available.pop_at(_random.randi_range(0, available.size() - 1)))
	return choices
