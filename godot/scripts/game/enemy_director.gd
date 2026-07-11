class_name EnemyDirector
extends Node2D

signal enemy_defeated

const EnemyScript := preload("res://scripts/game/enemy_unit.gd")

var vehicle: VehicleState
var player: CrewPlayer
var _random: RandomNumberGenerator
var current_wave: WaveDefinition
var remaining_budget: int = 0
var spawn_time: float = 0.0
var wave_elapsed: float = 0.0
var active: bool = false


func setup(vehicle_state: VehicleState, crew: CrewPlayer, random_stream: RandomNumberGenerator) -> void:
	vehicle = vehicle_state
	player = crew
	_random = random_stream


func _process(delta: float) -> void:
	if not active or current_wave == null:
		return
	wave_elapsed += delta
	spawn_time -= delta
	if spawn_time <= 0.0:
		spawn_enemy()
		spawn_time = current_wave.spawn_interval_seconds


func begin_wave(wave: WaveDefinition) -> void:
	current_wave = wave
	remaining_budget = wave.threat_budget
	spawn_time = wave.first_spawn_delay_seconds
	wave_elapsed = 0.0
	active = true
	set_enemy_activity(true)


func end_wave() -> void:
	active = false
	clear_enemies()


func spawn_enemy() -> EnemyUnit:
	if remaining_budget <= 0 or get_child_count() >= current_wave.max_alive_enemies:
		return null
	var definition: EnemyDefinition = _select_affordable_enemy()
	if definition == null:
		return null
	remaining_budget -= definition.threat_cost
	var front_only: bool = current_wave.first_front_only_seconds > 0.0 and wave_elapsed < current_wave.first_front_only_seconds
	var side: int = -1 if front_only or _random.randf() < current_wave.front_spawn_chance else 1
	var enemy := EnemyScript.new() as EnemyUnit
	add_child(enemy)
	enemy.setup(definition, side, vehicle, player)
	enemy.died.connect(_on_enemy_died)
	return enemy


func spawn_test_enemy(definition: EnemyDefinition) -> EnemyUnit:
	var enemy := EnemyScript.new() as EnemyUnit
	add_child(enemy)
	enemy.setup(definition, -1, vehicle, player)
	enemy.died.connect(_on_enemy_died)
	return enemy


func clear_enemies() -> void:
	for child: Node in get_children():
		child.queue_free()


func set_enemy_activity(value: bool) -> void:
	for child: Node in get_children():
		var enemy := child as EnemyUnit
		if enemy != null:
			enemy.active = value


func _select_affordable_enemy() -> EnemyDefinition:
	var candidates: Array[EnemyDefinition] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for index: int in current_wave.enemy_ids.size():
		var definition := GameCatalog.get_definition(current_wave.enemy_ids[index]) as EnemyDefinition
		if definition.threat_cost <= remaining_budget:
			candidates.append(definition)
			weights.append(current_wave.enemy_weights[index])
			total_weight += current_wave.enemy_weights[index]
	if candidates.is_empty():
		return null
	var roll: float = _random.randf() * total_weight
	var cumulative: float = 0.0
	for index: int in candidates.size():
		cumulative += weights[index]
		if roll <= cumulative:
			return candidates[index]
	return candidates.back()


func _on_enemy_died(_enemy: EnemyUnit) -> void:
	enemy_defeated.emit()
