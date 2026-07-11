class_name RunCoordinator
extends Node2D

const DEFAULT_RUN_SEED: int = 7192026
const RELIC_CHOICE_COUNT: int = 3
const BackgroundScript := preload("res://scripts/game/scrolling_background.gd")
const PlayerScript := preload("res://scripts/game/crew_player.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")
const HudScript := preload("res://scripts/ui/game_hud.gd")
const SmokeTestScript := preload("res://tests/run_smoke_test.gd")
const NetworkTestDriverScript := preload("res://tests/network_test_driver.gd")

@onready var stage_director: StageDirector = $StageDirector as StageDirector
@onready var enemy_director: EnemyDirector = $EnemyDirector as EnemyDirector
@onready var vehicle_state: VehicleState = $VehicleState as VehicleState
@onready var reward_system: RewardSystem = $RewardSystem as RewardSystem
@onready var net_state_replicator: NetStateReplicator = $NetStateReplicator as NetStateReplicator
@onready var revive_controller: ReviveController = $ReviveController as ReviveController
@onready var player_net_replicator: PlayerNetReplicator = $PlayerNetReplicator as PlayerNetReplicator
@onready var parallax_world: Node2D = $ParallaxWorld as Node2D
@onready var projectiles: Node2D = $Projectiles as Node2D

var random_streams := RunRandomStreams.new()
var player: CrewPlayer
var hud: GameHUD
var active_relic_choices: Array[RelicDefinition] = []
var players_by_peer: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	pass


func setup_network_run(run_seed: int) -> void:
	if _initialized:
		return
	_initialized = true
	random_streams.setup(run_seed)
	var waves: Array[WaveDefinition] = _load_waves()
	var relic_pool: Array[RelicDefinition] = _load_relics()
	parallax_world.add_child(BackgroundScript.new())
	vehicle_state.setup(GameCatalog.get_definition(&"vehicle_survival") as VehicleDefinition)
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

	var host_player := players_by_peer.get(NetworkSession.HOST_PEER_ID) as CrewPlayer
	enemy_director.setup(vehicle_state, host_player, random_streams.wave)
	enemy_director.authoritative = NetworkSession.is_host_authority()
	reward_system.setup(random_streams.reward, relic_pool)
	revive_controller.setup(players_by_peer, vehicle_state)
	_connect_systems()
	if not NetworkSession.is_host_authority():
		stage_director.process_mode = Node.PROCESS_MODE_DISABLED
	player_net_replicator.setup(self, players_by_peer)
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


func _connect_systems() -> void:
	stage_director.prepare_started.connect(_on_prepare_started)
	stage_director.combat_started.connect(_on_combat_started)
	stage_director.reward_requested.connect(_on_reward_requested)
	stage_director.victory_requested.connect(_on_victory_requested)
	enemy_director.enemy_defeated.connect(reward_system.record_enemy_defeat)
	vehicle_state.destroyed.connect(_on_vehicle_destroyed)
	hud.relic_selected.connect(select_relic)


func _on_prepare_started(_wave: WaveDefinition) -> void:
	_set_player_controls(true)
	hud.hide_overlay()
	enemy_director.set_enemy_activity(false)
	if NetworkSession.is_host_authority():
		net_state_replicator.broadcast_run_state()


func _on_combat_started(wave: WaveDefinition) -> void:
	_set_player_controls(true)
	if NetworkSession.is_host_authority():
		enemy_director.begin_wave(wave)
		net_state_replicator.broadcast_run_state()


func _on_reward_requested() -> void:
	if not NetworkSession.is_host_authority():
		return
	enemy_director.end_wave()
	_set_player_controls(false)
	active_relic_choices = reward_system.prepare_choices(RELIC_CHOICE_COUNT)
	hud.show_relic_choices(active_relic_choices)
	net_state_replicator.broadcast_run_state()
	net_state_replicator.broadcast_reward_choices(active_relic_choices)


func _on_victory_requested() -> void:
	if not NetworkSession.is_host_authority():
		return
	enemy_director.end_wave()
	_set_player_controls(false)
	hud.show_end(true, reward_system.kills, reward_system.acquired)
	net_state_replicator.broadcast_run_state()
	net_state_replicator.broadcast_result(true)


func select_relic(index: int) -> void:
	if not NetworkSession.is_host_authority() or index < 0 or index >= active_relic_choices.size():
		return
	var selected: RelicDefinition = reward_system.confirm_choice(index)
	for peer_key: Variant in players_by_peer:
		var crew := players_by_peer[peer_key] as CrewPlayer
		crew.apply_relic(selected)
	vehicle_state.apply_relic(selected)
	net_state_replicator.broadcast_relic_selected(selected.id)
	stage_director.complete_reward()


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


func _unhandled_input(event: InputEvent) -> void:
	if not NetworkSession.is_host_authority():
		return
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
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
