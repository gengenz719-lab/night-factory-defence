class_name RunSmokeTest
extends RefCounted

const CatalogFixtureScript := preload("res://tests/catalog_fixture_definition.gd")
const REQUIRED_RUN_NODES: Array[String] = [
	"StageDirector", "EnemyDirector", "VehicleState", "RewardSystem",
	"NetStateReplicator", "PlayerNetReplicator", "ReviveController",
	"VehicleModuleSystem", "ModuleNetReplicator",
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
	_test_modules(coordinator, failures)
	_test_characters(coordinator, failures)
	_test_player_survival(coordinator.player, failures)

	coordinator.stage_director.begin_combat()
	if coordinator.stage_director.state != StageDirector.RunState.COMBAT:
		failures.append("combat did not start")
	await _test_breach_invasion(coordinator, failures)
	coordinator.player.apply_network_input(Vector2.UP, Vector2.RIGHT, 1.0 / 30.0, false)
	if coordinator.player.on_floor:
		failures.append("network jump intent was not applied by authority")
	var budget_before: int = coordinator.enemy_director.remaining_budget
	var enemy: EnemyUnit = coordinator.enemy_director.spawn_enemy()
	await coordinator.get_tree().process_frame
	if enemy == null or coordinator.enemy_director.remaining_budget >= budget_before:
		failures.append("threat budget spawn failed")
	elif coordinator.enemy_director.remaining_budget < 0:
		failures.append("threat budget became negative")
	else:
		enemy.position = Vector2(700.0, 600.0)
		var turret_shots_before: int = coordinator.module_system.turret_shots
		coordinator.module_system.authority_tick(0.6)
		if coordinator.module_system.turret_shots <= turret_shots_before:
			failures.append("powered turret did not acquire and fire")
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
	coordinator.vehicle_state.take_attack(&"front", 160.0)
	if not is_equal_approx(float(coordinator.vehicle_state.section_hp[&"front"]), front_before - 160.0):
		failures.append("vehicle damage mismatch")
	coordinator.player.position = SurvivalVehicle.REPAIR_CONSOLE
	for _step: int in range(100):
		coordinator.vehicle_state.repair_at(coordinator.player.position, 0.1, 1.0)
	var combat_cap: float = float(coordinator.vehicle_state.max_section_hp[&"front"]) * coordinator.vehicle_state.definition.combat_repair_cap_ratio
	if not is_equal_approx(float(coordinator.vehicle_state.section_hp[&"front"]), combat_cap):
		failures.append("combat repair did not stop at 60 percent")

	coordinator.stage_director.finish_wave()
	if coordinator.stage_director.state != StageDirector.RunState.REWARD:
		failures.append("wave 1 did not enter reward")
	var plating_index: int = _find_relic(coordinator.active_relic_choices, &"relic_plating")
	var old_front_max: float = float(coordinator.vehicle_state.max_section_hp[&"front"])
	coordinator.select_relic(plating_index)
	if coordinator.stage_director.wave_number() != 2 or float(coordinator.vehicle_state.max_section_hp[&"front"]) <= old_front_max:
		failures.append("relic application mismatch")
	var supplies_before_seal: float = coordinator.vehicle_state.supplies
	coordinator.vehicle_state.repair_at(coordinator.player.position, 0.1, 1.0)
	if coordinator.vehicle_state.is_breached(&"roof") or not is_equal_approx(coordinator.vehicle_state.supplies, supplies_before_seal - coordinator.vehicle_state.definition.breach_seal_supply_cost):
		failures.append("wave break breach seal mismatch")
	for _step: int in range(150):
		coordinator.vehicle_state.repair_at(coordinator.player.position, 0.1, 1.0)
	if float(coordinator.vehicle_state.section_hp[&"front"]) < float(coordinator.vehicle_state.max_section_hp[&"front"]) - 0.1:
		failures.append("prepare repair did not reach 100 percent")

	coordinator.stage_director.begin_combat()
	coordinator.stage_director.finish_wave()
	if coordinator.stage_director.state != StageDirector.RunState.VICTORY:
		failures.append("wave 2 did not enter victory")
	return failures


func _test_breach_invasion(coordinator: RunCoordinator, failures: Array[String]) -> void:
	var vehicle: VehicleState = coordinator.vehicle_state
	vehicle.take_attack(&"roof", float(vehicle.max_section_hp[&"roof"]))
	if not vehicle.is_breached(&"roof"):
		failures.append("destroyed exterior did not open breach")
		return
	var workbench: VehicleModuleState = coordinator.module_system.workbench_module()
	var module_hp_before: float = workbench.hp
	var climber: EnemyUnit = coordinator.enemy_director.spawn_test_enemy(GameCatalog.get_definition(&"enemy_climber") as EnemyDefinition)
	climber.position = Vector2(SurvivalVehicle.LADDER_X, SurvivalVehicle.ROOF_FLOOR_Y - 15.0)
	await coordinator.get_tree().process_frame
	if climber.invasion_state != EnemyUnit.InvasionState.ENTERING or climber.entry_time <= 0.0:
		failures.append("climber invasion telegraph did not start")
	climber.entry_time = 0.0
	await coordinator.get_tree().process_frame
	if not climber.inside_vehicle or coordinator.enemy_director.invasions_confirmed <= 0:
		failures.append("climber did not enter through roof breach")
	climber.position = coordinator.module_system.grid_to_world(workbench.grid_position, workbench.definition.grid_size)
	climber.target_evaluation_time = 0.0
	climber.attack_cooldown = 0.0
	await coordinator.get_tree().process_frame
	if workbench.hp >= module_hp_before or coordinator.enemy_director.module_attacks_confirmed <= 0:
		failures.append("interior climber did not attack module")
	climber.queue_free()
	await coordinator.get_tree().process_frame


func _test_player_survival(player: CrewPlayer, failures: Array[String]) -> void:
	var start_x: float = player.position.x
	if not player.authority_request_dodge(Vector2.RIGHT, Vector2.RIGHT):
		failures.append("authority dodge was rejected")
	if not is_equal_approx(player.position.x - start_x, player.definition.dodge_distance_cells * CrewPlayer.CELL_SIZE_PX):
		failures.append("dodge distance mismatch")
	var hp_before: float = player.survival.hp
	player.take_damage(10.0)
	if not is_equal_approx(player.survival.hp, hp_before):
		failures.append("dodge invulnerability did not block damage")
	if player.authority_request_dodge(Vector2.RIGHT, Vector2.RIGHT):
		failures.append("dodge cooldown was not enforced")
	player.authority_tick(player.definition.dodge_invulnerability_seconds + 0.01)
	player.take_damage(9999.0)
	if not player.survival.is_downed or not is_equal_approx(player.survival.downed_time, player.definition.downed_grace_seconds):
		failures.append("downed duration mismatch")
	player.authority_add_revive_progress(player.definition.revive_seconds)
	if player.survival.is_downed or not is_equal_approx(player.survival.hp, player.survival.max_hp * player.definition.revive_health_ratio):
		failures.append("revive health mismatch")
	if not is_equal_approx(player.survival.invulnerable_time, player.definition.revive_invulnerability_seconds):
		failures.append("revive invulnerability mismatch")
	player.authority_tick(player.definition.revive_invulnerability_seconds + 0.01)
	player.take_damage(9999.0)
	player.authority_tick(player.definition.downed_grace_seconds + 0.01)
	if not player.survival.is_departed or not is_equal_approx(player.survival.return_time, player.definition.return_wait_seconds):
		failures.append("departure transition mismatch")
	player.authority_tick(player.definition.return_wait_seconds + 0.01)
	if player.survival.is_departed or not is_equal_approx(player.survival.hp, player.survival.max_hp * player.definition.return_health_ratio):
		failures.append("post-departure return mismatch")


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


func _test_modules(coordinator: RunCoordinator, failures: Array[String]) -> void:
	var system: VehicleModuleSystem = coordinator.module_system
	for module_id: StringName in [&"module_generator", &"module_firing_port", &"module_turret", &"module_workbench"]:
		if GameCatalog.get_definition(module_id) is not ModuleDefinition:
			failures.append("module definition missing: %s" % module_id)
	if system.modules.size() != 4 or system.power_generated != 6 or system.power_requested != 1:
		failures.append("initial module layout or power mismatch")
	var workbench_definition := GameCatalog.get_definition(&"module_workbench") as ModuleDefinition
	if not system.validate_placement(workbench_definition, Vector2i(system.vehicle_definition.ladder_column, 1)).contains("はしご"):
		failures.append("ladder blocking placement was not rejected")
	var passage_test := VehicleModuleSystem.new()
	passage_test.setup(system.vehicle_definition, null)
	for x_value: int in [1, 2, 3, 4]:
		passage_test.place_confirmed(passage_test.next_instance_id, &"module_firing_port", Vector2i(x_value, 1), false)
	var firing_port := GameCatalog.get_definition(&"module_firing_port") as ModuleDefinition
	if not passage_test.validate_placement(firing_port, Vector2i(6, 1)).contains("通路"):
		failures.append("last passage cell placement was not rejected")
	passage_test.free()
	var first_turret_id: int = system.request_place(&"module_turret", Vector2i(2, 0))
	if first_turret_id <= 0:
		failures.append("turret placement failed")
		return
	var second_turret: VehicleModuleState = system.place_confirmed(system.next_instance_id, &"module_turret", Vector2i(4, 0), false)
	var workbench: VehicleModuleState = system.active_workbench()
	system.set_priority(workbench.instance_id, 3)
	system.set_priority(first_turret_id, 2)
	system.set_priority(second_turret.instance_id, 1)
	if not (workbench.powered and (system.modules[first_turret_id] as VehicleModuleState).powered and not second_turret.powered):
		failures.append("power shortage did not stop lowest priority module")
	var turret: VehicleModuleState = system.modules[first_turret_id]
	turret.heat = turret.definition.heat_limit
	turret.overheated = true
	turret.overheat_time = turret.definition.overheat_stop_seconds
	system.authority_tick(3.4)
	if turret.overheated or turret.heat > turret.definition.overheat_recovery_heat:
		failures.append("turret did not recover after forced cooling")


func _test_characters(coordinator: RunCoordinator, failures: Array[String]) -> void:
	var gunner := GameCatalog.get_definition(&"character_gunner") as CharacterDefinition
	var engineer := GameCatalog.get_definition(&"character_engineer") as CharacterDefinition
	if gunner == null or engineer == null or gunner.starting_weapon_id == engineer.starting_weapon_id:
		failures.append("two character definitions or starting weapons missing")
		return
	if coordinator.player.definition.id != &"character_gunner" or not is_equal_approx(coordinator.player.damage_multiplier, 1.1):
		failures.append("gunner selection or passive mismatch")
	var normal_interval: float = 1.0 / coordinator.player.weapon_definition.shots_per_second
	if not coordinator.player.authority_request_ability() or coordinator.player.effective_fire_interval() >= normal_interval:
		failures.append("combat focus did not increase attack speed")
	if coordinator.player.effective_reload_seconds() >= coordinator.player.weapon_definition.reload_seconds:
		failures.append("combat focus did not increase reload speed")
	var engineer_player := CrewPlayer.new()
	coordinator.add_child(engineer_player)
	engineer_player.setup(coordinator.vehicle_state, engineer, GameCatalog.get_definition(engineer.starting_weapon_id) as WeaponDefinition)
	coordinator.vehicle_state.take_attack(&"front", 24.0)
	var damaged_hp: float = float(coordinator.vehicle_state.section_hp[&"front"])
	var supplies_before: float = coordinator.vehicle_state.supplies
	if not engineer_player.authority_request_ability():
		failures.append("repair drone activation rejected")
	engineer_player.authority_tick(1.0)
	if float(coordinator.vehicle_state.section_hp[&"front"]) < damaged_hp + 11.9:
		failures.append("repair drone did not repair 12 HP/s")
	if not is_equal_approx(coordinator.vehicle_state.supplies, supplies_before):
		failures.append("repair drone consumed supplies")
	engineer_player.queue_free()


func _test_foundation_configuration(coordinator: RunCoordinator, failures: Array[String]) -> void:
	if NetworkSession.role != NetworkSession.SessionRole.SOLO or NetworkSession.local_peer_id() != NetworkSession.HOST_PEER_ID:
		failures.append("solo did not use the offline multiplayer path")
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
