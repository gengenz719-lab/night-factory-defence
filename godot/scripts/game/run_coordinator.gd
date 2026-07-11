class_name RunCoordinator
extends Node2D

const DEFAULT_RUN_SEED: int = 7192026
const RELIC_CHOICE_COUNT: int = 3
const BackgroundScript := preload("res://scripts/game/scrolling_background.gd")
const PlayerScript := preload("res://scripts/game/crew_player.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")
const HudScript := preload("res://scripts/ui/game_hud.gd")
const SmokeTestScript := preload("res://tests/run_smoke_test.gd")

@onready var stage_director: StageDirector = $StageDirector as StageDirector
@onready var enemy_director: EnemyDirector = $EnemyDirector as EnemyDirector
@onready var vehicle_state: VehicleState = $VehicleState as VehicleState
@onready var reward_system: RewardSystem = $RewardSystem as RewardSystem
@onready var parallax_world: Node2D = $ParallaxWorld as Node2D
@onready var projectiles: Node2D = $Projectiles as Node2D

var random_streams := RunRandomStreams.new()
var player: CrewPlayer
var hud: GameHUD
var weapon_definition: WeaponDefinition
var active_relic_choices: Array[RelicDefinition] = []


func _ready() -> void:
	random_streams.setup(DEFAULT_RUN_SEED)
	var waves: Array[WaveDefinition] = _load_waves()
	var relic_pool: Array[RelicDefinition] = _load_relics()
	var character := GameCatalog.get_definition(&"character_survivor") as CharacterDefinition
	weapon_definition = GameCatalog.get_definition(character.starting_weapon_id) as WeaponDefinition

	parallax_world.add_child(BackgroundScript.new())
	vehicle_state.setup(GameCatalog.get_definition(&"vehicle_survival") as VehicleDefinition)
	player = PlayerScript.new() as CrewPlayer
	$Players.add_child(player)
	player.setup(vehicle_state, character, weapon_definition)
	hud = HudScript.new() as GameHUD
	add_child(hud)

	enemy_director.setup(vehicle_state, player, random_streams.wave)
	reward_system.setup(random_streams.reward, relic_pool)
	_connect_systems()
	stage_director.setup(waves)
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred(&"_run_smoke_test")


func _process(_delta: float) -> void:
	hud.update_status(
		stage_director.wave_number(), stage_director.wave_definitions.size(),
		stage_director.state_text(), maxf(0.0, stage_director.state_time),
		player, vehicle_state, reward_system.kills, reward_system.acquired
	)


func _connect_systems() -> void:
	stage_director.prepare_started.connect(_on_prepare_started)
	stage_director.combat_started.connect(_on_combat_started)
	stage_director.reward_requested.connect(_on_reward_requested)
	stage_director.victory_requested.connect(_on_victory_requested)
	enemy_director.enemy_defeated.connect(reward_system.record_enemy_defeat)
	vehicle_state.destroyed.connect(_on_vehicle_destroyed)
	player.shoot_requested.connect(_on_player_shoot)
	hud.relic_selected.connect(select_relic)


func _on_prepare_started(_wave: WaveDefinition) -> void:
	player.controls_enabled = true
	hud.hide_overlay()
	enemy_director.set_enemy_activity(false)


func _on_combat_started(wave: WaveDefinition) -> void:
	player.controls_enabled = true
	enemy_director.begin_wave(wave)


func _on_reward_requested() -> void:
	enemy_director.end_wave()
	player.controls_enabled = false
	active_relic_choices = reward_system.prepare_choices(RELIC_CHOICE_COUNT)
	hud.show_relic_choices(active_relic_choices)


func _on_victory_requested() -> void:
	enemy_director.end_wave()
	player.controls_enabled = false
	hud.show_end(true, reward_system.kills, reward_system.acquired)


func select_relic(index: int) -> void:
	var selected: RelicDefinition = reward_system.confirm_choice(index)
	player.apply_relic(selected)
	vehicle_state.apply_relic(selected)
	stage_director.complete_reward()


func _on_player_shoot(origin: Vector2, direction: Vector2, damage: float) -> void:
	if stage_director.state != StageDirector.RunState.COMBAT:
		return
	var projectile := ProjectileScript.new() as PlayerProjectile
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, damage, weapon_definition)


func _on_vehicle_destroyed() -> void:
	if stage_director.state in [StageDirector.RunState.VICTORY, StageDirector.RunState.DEFEAT]:
		return
	stage_director.mark_defeat()
	player.controls_enabled = false
	enemy_director.set_enemy_activity(false)
	hud.show_end(false, reward_system.kills, reward_system.acquired)


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
