class_name RunSmokeTest
extends RefCounted

const CatalogFixtureScript := preload("res://tests/catalog_fixture_definition.gd")
const REQUIRED_RUN_NODES: Array[String] = [
	"StageDirector", "EnemyDirector", "VehicleState", "RewardSystem",
]
const REQUIRED_INPUT_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"jump", &"drop_down", &"aim",
	&"fire_primary", &"fire_secondary", &"dodge", &"interact", &"ability",
	&"ping", &"pause", &"ready_toggle",
]
const REQUIRED_PHYSICS_LAYERS: Array[String] = [
	"Player", "PlayerProjectile", "Enemy", "EnemyProjectile", "VehicleInterior",
	"VehicleExterior", "Module", "Interactable", "Pickup", "Hazard",
]


func run(coordinator: RunCoordinator) -> Array[String]:
	var failures: Array[String] = []
	await coordinator.get_tree().process_frame
	_test_catalog(failures)
	_test_deterministic_rewards(failures)
	_test_foundation_configuration(coordinator, failures)

	coordinator.stage_director.begin_combat()
	if coordinator.stage_director.state != StageDirector.RunState.COMBAT:
		failures.append("combat did not start")
	var budget_before: int = coordinator.enemy_director.remaining_budget
	var enemy: EnemyUnit = coordinator.enemy_director.spawn_enemy()
	await coordinator.get_tree().process_frame
	if enemy == null or coordinator.enemy_director.remaining_budget >= budget_before:
		failures.append("threat budget spawn failed")
	elif coordinator.enemy_director.remaining_budget < 0:
		failures.append("threat budget became negative")
	else:
		enemy.take_damage(9999.0)
		await coordinator.get_tree().process_frame
		if coordinator.reward_system.kills != 1:
			failures.append("enemy kill was not counted")

	for enemy_id: StringName in [&"enemy_walker", &"enemy_runner", &"enemy_climber"]:
		var visual_enemy: EnemyUnit = coordinator.enemy_director.spawn_test_enemy(GameCatalog.get_definition(enemy_id) as EnemyDefinition)
		await coordinator.get_tree().process_frame
		if visual_enemy.get_child_count() == 0:
			failures.append("enemy visual missing: %s" % enemy_id)
		visual_enemy.queue_free()
	await coordinator.get_tree().process_frame

	var front_before: float = float(coordinator.vehicle_state.section_hp[&"front"])
	coordinator.vehicle_state.take_attack(&"front", 50.0)
	if not is_equal_approx(float(coordinator.vehicle_state.section_hp[&"front"]), front_before - 50.0):
		failures.append("vehicle damage mismatch")
	coordinator.player.position = SurvivalVehicle.REPAIR_CONSOLE
	for _step: int in range(30):
		coordinator.vehicle_state.repair_at(coordinator.player.position, 0.1, 1.0)
	if float(coordinator.vehicle_state.section_hp[&"front"]) <= front_before - 50.0:
		failures.append("vehicle repair did not restore damage")

	coordinator.stage_director.finish_wave()
	if coordinator.stage_director.state != StageDirector.RunState.REWARD:
		failures.append("wave 1 did not enter reward")
	var plating_index: int = _find_relic(coordinator.active_relic_choices, &"relic_plating")
	var old_front_max: float = float(coordinator.vehicle_state.max_section_hp[&"front"])
	coordinator.select_relic(plating_index)
	if coordinator.stage_director.wave_number() != 2 or float(coordinator.vehicle_state.max_section_hp[&"front"]) <= old_front_max:
		failures.append("relic application mismatch")

	coordinator.stage_director.begin_combat()
	coordinator.stage_director.finish_wave()
	if coordinator.stage_director.state != StageDirector.RunState.VICTORY:
		failures.append("wave 2 did not enter victory")
	return failures


func _test_catalog(failures: Array[String]) -> void:
	for error: String in GameCatalog.reload_catalog():
		failures.append("catalog: %s" % error)
	if GameCatalog.get_all_definitions().size() != GameCatalog.DEFINITION_PATHS.size():
		failures.append("catalog definition count mismatch")
	var empty := GameDefinition.new()
	var duplicate_a := GameDefinition.new()
	var duplicate_b := GameDefinition.new()
	duplicate_a.id = &"test_duplicate"
	duplicate_b.id = &"test_duplicate"
	var missing := CatalogFixtureScript.new() as CatalogFixtureDefinition
	missing.id = &"test_missing"
	missing.referenced_ids = [&"test_not_registered"]
	var invalid_definitions: Array[GameDefinition] = [empty, duplicate_a, duplicate_b, missing]
	if GameCatalog.validate_definitions(invalid_definitions).size() != 3:
		failures.append("catalog validation coverage mismatch")


func _test_foundation_configuration(coordinator: RunCoordinator, failures: Array[String]) -> void:
	for node_name: String in REQUIRED_RUN_NODES:
		if coordinator.get_node_or_null(node_name) == null:
			failures.append("run-owned system missing: %s" % node_name)
	for autoload_name: String in ["AppState", "GameCatalog", "NetworkSession", "SaveService", "AudioService"]:
		if coordinator.get_node_or_null("/root/%s" % autoload_name) == null:
			failures.append("autoload missing: %s" % autoload_name)
	for action_name: StringName in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action_name):
			failures.append("input action missing: %s" % action_name)
	for layer_index: int in REQUIRED_PHYSICS_LAYERS.size():
		var setting_name: String = "layer_names/2d_physics/layer_%d" % (layer_index + 1)
		if str(ProjectSettings.get_setting(setting_name, "")) != REQUIRED_PHYSICS_LAYERS[layer_index]:
			failures.append("physics layer mismatch: %s" % setting_name)


func _test_deterministic_rewards(failures: Array[String]) -> void:
	var pool: Array[RelicDefinition] = []
	for definition: GameDefinition in GameCatalog.get_definitions_with_tag(&"relic"):
		pool.append(definition as RelicDefinition)
	var streams_a := RunRandomStreams.new()
	var streams_b := RunRandomStreams.new()
	streams_a.setup(123456)
	streams_b.setup(123456)
	var rewards_a := RewardSystem.new()
	var rewards_b := RewardSystem.new()
	rewards_a.setup(streams_a.reward, pool)
	rewards_b.setup(streams_b.reward, pool)
	rewards_a.prepare_choices(3)
	rewards_b.prepare_choices(3)
	if rewards_a.choice_ids() != rewards_b.choice_ids():
		failures.append("reward seed was not deterministic")
	if streams_a.wave.seed == streams_a.reward.seed or streams_a.visual.seed == streams_a.wave.seed:
		failures.append("random streams were not separated")
	rewards_a.free()
	rewards_b.free()


func _find_relic(choices: Array[RelicDefinition], relic_id: StringName) -> int:
	for index: int in choices.size():
		if choices[index].id == relic_id:
			return index
	return -1
