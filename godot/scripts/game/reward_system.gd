class_name RewardSystem
extends Node

var _random: RandomNumberGenerator
var _pool: Array[RelicDefinition] = []
var _choices: Array[RelicDefinition] = []
var acquired: Array[RelicDefinition] = []
var kills: int = 0


func setup(random_stream: RandomNumberGenerator, relic_pool: Array[RelicDefinition]) -> void:
	_random = random_stream
	_pool = relic_pool


func prepare_choices(choice_count: int) -> Array[RelicDefinition]:
	var available: Array[RelicDefinition] = _pool.duplicate()
	_choices.clear()
	while not available.is_empty() and _choices.size() < choice_count:
		var index: int = _random.randi_range(0, available.size() - 1)
		_choices.append(available.pop_at(index))
	return _choices.duplicate()


func confirm_choice(index: int) -> RelicDefinition:
	var selected: RelicDefinition = _choices[index]
	acquired.append(selected)
	return selected


func record_enemy_defeat() -> void:
	kills += 1


func choice_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for relic: RelicDefinition in _choices:
		result.append(relic.id)
	return result
