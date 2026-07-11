class_name RunCoordinator
extends Node2D

const DEFAULT_RUN_SEED: int = 7192026
const BackgroundScript := preload("res://scripts/game/scrolling_background.gd")
const PlayerScript := preload("res://scripts/game/crew_player.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")
const HudScript := preload("res://scripts/ui/game_hud.gd")
const SmokeTestScript := preload("res://tests/run_smoke_test.gd")
const NetworkTestDriverScript := preload("res://tests/network_test_driver.gd")
const BuildUiScript := preload("res://scripts/ui/vehicle_build_ui.gd")

@onready var stage_director: StageDirector = $StageDirector as StageDirector
@onready var enemy_director: EnemyDirector = $EnemyDirector as EnemyDirector
@onready var vehicle_state: VehicleState = $VehicleState as VehicleState
@onready var reward_system: RewardSystem = $RewardSystem as RewardSystem
@onready var net_state_replicator: NetStateReplicator = $NetStateReplicator as NetStateReplicator
@onready var revive_controller: ReviveController = $ReviveController as ReviveController
@onready var player_net_replicator: PlayerNetReplicator = $PlayerNetReplicator as PlayerNetReplicator
@onready var module_system: VehicleModuleSystem = $VehicleModuleSystem as VehicleModuleSystem
@onready var module_net_replicator: ModuleNetReplicator = $ModuleNetReplicator as ModuleNetReplicator
@onready var vote_controller: VoteController = $VoteController as VoteController
@onready var parallax_world: Node2D = $ParallaxWorld as Node2D
@onready var projectiles: Node2D = $Projectiles as Node2D

var random_streams := RunRandomStreams.new()
var player: CrewPlayer
var hud: GameHUD
var build_ui: VehicleBuildUI
var active_relic_choices: Array[RelicDefinition] = []
var active_route_choices: Array[RouteNodeDefinition] = []
var selected_route: RouteNodeDefinition
var route_generator := RouteGenerator.new()
var vote_rules: VoteRulesDefinition
var players_by_peer: Dictionary = {}
var _initialized: bool = false
var _selected_route_reward_applied: bool = true


func _ready() -> void:
	pass


func setup_network_run(run_seed: int) -> void:
	if _initialized:
		return
	_initialized = true
	random_streams.setup(run_seed)
	var waves: Array[WaveDefinition] = _load_waves()
	var relic_pool: Array[RelicDefinition] = _load_relics()
	var route_pool: Array[RouteNodeDefinition] = _load_routes()
	vote_rules = GameCatalog.get_definition(&"vote_default") as VoteRulesDefinition
	route_generator.setup(random_streams.route, route_pool)
	parallax_world.add_child(BackgroundScript.new())
	var vehicle_definition := GameCatalog.get_definition(&"vehicle_survival") as VehicleDefinition
	vehicle_state.setup(vehicle_definition)
	module_system.setup(vehicle_definition, enemy_director)
	vehicle_state.module_system = module_system
	var peer_ids: Array[int] = NetworkSession.connected_peer_ids()
	for roster_index: int in peer_ids.size():
		var peer_id: int = peer_ids[roster_index]
		var character_id: StringName = NetworkSession.selected_character(peer_id)
		if character_id.is_empty():
			character_id = &"character_gunner"
		var character := GameCatalog.get_definition(character_id) as CharacterDefinition
		var starting_weapon := GameCatalog.get_definition(character.starting_weapon_id) as WeaponDefinition
		var crew := PlayerScript.new() as CrewPlayer
		crew.name = "Player%d" % peer_id
		$Players.add_child(crew)
		crew.setup(vehicle_state, character, starting_weapon)
		crew.peer_id = peer_id
		crew.network_controlled = true
		crew.position.x += float(roster_index) * 62.0
		crew.replica_target_position = crew.position
		players_by_peer[peer_id] = crew
	player = players_by_peer.get(NetworkSession.local_peer_id()) as CrewPlayer
	hud = HudScript.new() as GameHUD
	add_child(hud)
	build_ui = BuildUiScript.new() as VehicleBuildUI
	add_child(build_ui)
	build_ui.setup(module_system)
	build_ui.placement_requested.connect(module_net_replicator.request_place)
	build_ui.priority_requested.connect(module_net_replicator.request_priority)

	var host_player := players_by_peer.get(NetworkSession.HOST_PEER_ID) as CrewPlayer
	enemy_director.setup(vehicle_state, host_player, random_streams.wave, players_by_peer, module_system)
	enemy_director.authoritative = NetworkSession.is_host_authority()
	reward_system.setup(random_streams.reward, relic_pool)
	vote_controller.setup(self, vote_rules, random_streams.reward, random_streams.route)
	revive_controller.setup(players_by_peer, vehicle_state)
	_connect_systems()
	if not NetworkSession.is_host_authority():
		stage_director.process_mode = Node.PROCESS_MODE_DISABLED
	player_net_replicator.setup(self, players_by_peer)
	module_net_replicator.setup(self, module_system)
	module_net_replicator.request_rejected.connect(build_ui.show_message)
	net_state_replicator.setup(self)
	stage_director.setup(waves)
	var network_test_driver := NetworkTestDriverScript.new() as NetworkTestDriver
	add_child(network_test_driver)
	network_test_driver.setup(self)
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred(&"_run_smoke_test")


func _process(_delta: float) -> void:
	if not _initialized:
		return
	hud.update_status(
		stage_director.wave_number(), stage_director.wave_definitions.size(),
		stage_director.state_text(), maxf(0.0, stage_director.state_time),
		player, vehicle_state, reward_system.kills, reward_system.acquired
	)
	hud.update_team_status(players_by_peer, NetworkSession.local_peer_id(), reward_system.kills)
	if vote_controller.active_kind != VoteController.VoteKind.NONE:
		hud.update_vote_status(vote_controller.vote_count_text(), vote_controller.remaining_time)
	build_ui.refresh()


func _connect_systems() -> void:
	stage_director.prepare_started.connect(_on_prepare_started)
	stage_director.combat_started.connect(_on_combat_started)
	stage_director.reward_requested.connect(_on_reward_requested)
	stage_director.victory_requested.connect(_on_victory_requested)
	enemy_director.enemy_defeated.connect(reward_system.record_enemy_defeat)
	vehicle_state.destroyed.connect(_on_vehicle_destroyed)
	hud.relic_selected.connect(select_relic)
	hud.route_selected.connect(select_route)
	vote_controller.vote_resolved.connect(_on_vote_resolved)


func _on_prepare_started(_wave: WaveDefinition) -> void:
	vehicle_state.combat_active = false
	module_system.combat_active = false
	module_system.can_edit = true
	build_ui.set_prepare_mode(true)
	_set_player_controls(true)
	hud.hide_overlay()
	enemy_director.set_enemy_activity(false)
	if NetworkSession.is_host_authority():
		net_state_replicator.broadcast_run_state()


func _on_combat_started(wave: WaveDefinition) -> void:
	vehicle_state.combat_active = true
	module_system.combat_active = true
	module_system.can_edit = false
	build_ui.set_prepare_mode(false)
	_set_player_controls(true)
	if NetworkSession.is_host_authority():
		enemy_director.begin_wave(wave)
		net_state_replicator.broadcast_run_state()


func _on_reward_requested() -> void:
	if not NetworkSession.is_host_authority():
		return
	enemy_director.end_wave()
	vehicle_state.combat_active = false
	module_system.combat_active = false
	module_system.can_edit = false
	_set_player_controls(false)
	_apply_selected_route_reward()
	active_relic_choices = reward_system.prepare_choices(vote_rules.relic_choice_count)
	hud.show_relic_choices(active_relic_choices)
	net_state_replicator.broadcast_run_state()
	net_state_replicator.broadcast_reward_choices(active_relic_choices)
	vote_controller.start_vote(VoteController.VoteKind.RELIC, active_relic_choices.size())


func _on_victory_requested() -> void:
	if not NetworkSession.is_host_authority():
		return
	enemy_director.end_wave()
	_apply_selected_route_reward()
	_set_player_controls(false)
	hud.show_end(true, reward_system.kills, reward_system.acquired)
	net_state_replicator.broadcast_run_state()
	net_state_replicator.broadcast_result(true)


func select_relic(index: int) -> void:
	if index < 0 or index >= active_relic_choices.size() or vote_controller.active_kind != VoteController.VoteKind.RELIC:
		return
	vote_controller.request_vote(index)


func select_route(index: int) -> void:
	if index < 0 or index >= active_route_choices.size() or vote_controller.active_kind != VoteController.VoteKind.ROUTE:
		return
	vote_controller.request_vote(index)


func _on_vote_resolved(kind: VoteController.VoteKind, index: int) -> void:
	if not NetworkSession.is_host_authority():
		return
	if kind == VoteController.VoteKind.RELIC:
		_confirm_relic(index)
		_begin_route_vote()
	elif kind == VoteController.VoteKind.ROUTE:
		_confirm_route(index)


func _confirm_relic(index: int) -> void:
	var selected: RelicDefinition = reward_system.confirm_choice(index)
	for peer_key: Variant in players_by_peer:
		var crew := players_by_peer[peer_key] as CrewPlayer
		crew.apply_relic(selected)
	vehicle_state.apply_relic(selected)
	net_state_replicator.broadcast_relic_selected(selected.id)


func _begin_route_vote() -> void:
	active_route_choices = route_generator.generate_choices(vote_rules.route_choice_count)
	hud.show_route_choices(active_route_choices)
	net_state_replicator.broadcast_route_choices(active_route_choices)
	vote_controller.start_vote(VoteController.VoteKind.ROUTE, active_route_choices.size())


func _confirm_route(index: int) -> void:
	selected_route = active_route_choices[index]
	_selected_route_reward_applied = false
	enemy_director.current_route = selected_route
	net_state_replicator.broadcast_route_selected(selected_route.id)
	stage_director.complete_reward()


func _apply_selected_route_reward() -> void:
	if selected_route == null or _selected_route_reward_applied:
		return
	module_system.scrap += selected_route.scrap_reward
	vehicle_state.supplies += selected_route.supply_reward
	_selected_route_reward_applied = true
	net_state_replicator.broadcast_route_reward()


func spawn_authoritative_projectile(shooter: CrewPlayer, direction: Vector2) -> void:
	if stage_director.state != StageDirector.RunState.COMBAT:
		return
	var projectile := ProjectileScript.new() as PlayerProjectile
	projectiles.add_child(projectile)
	projectile.setup(
		shooter.position + direction * 38.0, direction,
		shooter.weapon_definition.damage_per_shot * shooter.damage_multiplier,
		shooter.weapon_definition, true
	)


func spawn_cosmetic_projectile(shooter: CrewPlayer, direction: Vector2) -> void:
	spawn_cosmetic_projectile_at(shooter.position + direction * 38.0, direction, shooter.weapon_definition.id)


func spawn_cosmetic_projectile_at(origin: Vector2, direction: Vector2, weapon_id: StringName) -> void:
	var projectile := ProjectileScript.new() as PlayerProjectile
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, 0.0, GameCatalog.get_definition(weapon_id) as WeaponDefinition, false)


func _on_vehicle_destroyed() -> void:
	if stage_director.state in [StageDirector.RunState.VICTORY, StageDirector.RunState.DEFEAT]:
		return
	stage_director.mark_defeat()
	_set_player_controls(false)
	enemy_director.set_enemy_activity(false)
	hud.show_end(false, reward_system.kills, reward_system.acquired)
	net_state_replicator.broadcast_run_state()
	net_state_replicator.broadcast_result(false)


func apply_stage_snapshot(state: int, wave_index: int, time_left: float) -> void:
	stage_director.state = state
	stage_director.wave_index = clampi(wave_index, 0, stage_director.wave_definitions.size() - 1)
	stage_director.state_time = time_left
	match stage_director.state:
		StageDirector.RunState.PREPARE, StageDirector.RunState.COMBAT:
			_set_player_controls(true)
			hud.hide_overlay()
		StageDirector.RunState.REWARD:
			_set_player_controls(false)
		StageDirector.RunState.VICTORY:
			_set_player_controls(false)
			hud.show_end(true, reward_system.kills, reward_system.acquired)
		StageDirector.RunState.DEFEAT:
			_set_player_controls(false)
			hud.show_end(false, reward_system.kills, reward_system.acquired)
	var is_prepare: bool = stage_director.state == StageDirector.RunState.PREPARE
	vehicle_state.combat_active = stage_director.state == StageDirector.RunState.COMBAT
	module_system.combat_active = vehicle_state.combat_active
	module_system.can_edit = is_prepare
	build_ui.set_prepare_mode(is_prepare)


func receive_reward_choices(first_id: String, second_id: String, third_id: String) -> void:
	active_relic_choices = [
		GameCatalog.get_definition(StringName(first_id)) as RelicDefinition,
		GameCatalog.get_definition(StringName(second_id)) as RelicDefinition,
		GameCatalog.get_definition(StringName(third_id)) as RelicDefinition,
	]
	hud.show_relic_choices(active_relic_choices)


func receive_relic_selected(relic_id: StringName) -> void:
	var selected := GameCatalog.get_definition(relic_id) as RelicDefinition
	reward_system.acquired.append(selected)
	for peer_key: Variant in players_by_peer:
		var crew := players_by_peer[peer_key] as CrewPlayer
		crew.apply_relic(selected)
	vehicle_state.apply_relic(selected)


func receive_route_choices(first_id: String, second_id: String) -> void:
	active_route_choices = [
		GameCatalog.get_definition(StringName(first_id)) as RouteNodeDefinition,
		GameCatalog.get_definition(StringName(second_id)) as RouteNodeDefinition,
	]
	hud.show_route_choices(active_route_choices)


func receive_route_selected(route_id: StringName) -> void:
	selected_route = GameCatalog.get_definition(route_id) as RouteNodeDefinition
	enemy_director.current_route = selected_route
	stage_director.wave_index += 1
	stage_director.state = StageDirector.RunState.PREPARE
	stage_director.state_time = stage_director.current_wave().prepare_duration_seconds
	_set_player_controls(true)
	hud.hide_overlay()


func receive_result(victory: bool, kills: int, first_relic_id: String, second_relic_id: String, third_relic_id: String) -> void:
	reward_system.kills = kills
	reward_system.acquired.clear()
	for relic_id: String in [first_relic_id, second_relic_id, third_relic_id]:
		if not relic_id.is_empty():
			reward_system.acquired.append(GameCatalog.get_definition(StringName(relic_id)) as RelicDefinition)
	hud.show_end(victory, reward_system.kills, reward_system.acquired)


func _set_player_controls(value: bool) -> void:
	for peer_key: Variant in players_by_peer:
		var crew := players_by_peer[peer_key] as CrewPlayer
		crew.controls_enabled = value


func _load_waves() -> Array[WaveDefinition]:
	var result: Array[WaveDefinition] = []
	for definition: GameDefinition in GameCatalog.get_definitions_with_tag(&"wave"):
		result.append(definition as WaveDefinition)
	result.sort_custom(func(a: WaveDefinition, b: WaveDefinition) -> bool: return a.wave_number < b.wave_number)
	return result


func _load_relics() -> Array[RelicDefinition]:
	var result: Array[RelicDefinition] = []
	for definition: GameDefinition in GameCatalog.get_definitions_with_tag(&"relic"):
		result.append(definition as RelicDefinition)
	return result


func _load_routes() -> Array[RouteNodeDefinition]:
	var result: Array[RouteNodeDefinition] = []
	for definition: GameDefinition in GameCatalog.get_definitions_with_tag(&"route"):
		result.append(definition as RouteNodeDefinition)
	result.sort_custom(func(a: RouteNodeDefinition, b: RouteNodeDefinition) -> bool: return a.id < b.id)
	return result


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_B:
		build_ui.toggle()
		return
	if not NetworkSession.is_host_authority():
		return
	if key_event.keycode == KEY_F1 and stage_director.state == StageDirector.RunState.PREPARE:
		stage_director.begin_combat()
	elif key_event.keycode == KEY_F2 and stage_director.state == StageDirector.RunState.COMBAT:
		stage_director.finish_wave()
	elif key_event.keycode == KEY_R and stage_director.state in [StageDirector.RunState.VICTORY, StageDirector.RunState.DEFEAT]:
		get_tree().reload_current_scene()


func _run_smoke_test() -> void:
	var tester: RunSmokeTest = SmokeTestScript.new() as RunSmokeTest
	var failures: Array[String] = await tester.run(self)
	if failures.is_empty():
		print("SMOKE_TEST_PASS wave=%d kills=%d hull=%.0f relic=%s catalog=%d" % [
			stage_director.wave_number(), reward_system.kills, vehicle_state.hull,
			reward_system.acquired[0].fallback_display_name,
			GameCatalog.get_all_definitions().size(),
		])
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("SMOKE_TEST_FAIL: %s" % failure)
		get_tree().quit(1)
