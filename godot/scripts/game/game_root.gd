extends Node2D

const BackgroundScript := preload("res://scripts/game/scrolling_background.gd")
const VehicleScript := preload("res://scripts/vehicle/survival_vehicle.gd")
const PlayerScript := preload("res://scripts/actors/crew_player.gd")
const EnemyScript := preload("res://scripts/actors/enemy_unit.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")
const HudScript := preload("res://scripts/ui/game_hud.gd")

enum RunState { PREPARE, COMBAT, REWARD, VICTORY, DEFEAT }

const WAVE_DURATION: float = 90.0
const PREPARE_DURATION: float = 10.0
const MAX_WAVE: int = 2

var state: RunState = RunState.PREPARE
var wave: int = 1
var state_time: float = PREPARE_DURATION
var spawn_time: float = 0.0
var kills: int = 0
var relics: Array[String] = []
var rng := RandomNumberGenerator.new()

var background: ScrollingBackground
var vehicle: SurvivalVehicle
var player: CrewPlayer
var hud: GameHUD


func _ready() -> void:
	_ensure_input_map()
	rng.seed = 7192026

	background = BackgroundScript.new() as ScrollingBackground
	add_child(background)

	vehicle = VehicleScript.new() as SurvivalVehicle
	add_child(vehicle)
	vehicle.destroyed.connect(_on_vehicle_destroyed)

	player = PlayerScript.new() as CrewPlayer
	add_child(player)
	player.setup(vehicle)
	player.shoot_requested.connect(_on_player_shoot)

	hud = HudScript.new() as GameHUD
	add_child(hud)
	hud.relic_selected.connect(_on_relic_selected)

	_begin_prepare()
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred(&"_run_smoke_test")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"restart") and state in [RunState.VICTORY, RunState.DEFEAT]:
		get_tree().reload_current_scene()
		return

	match state:
		RunState.PREPARE:
			state_time -= delta
			if Input.is_action_just_pressed(&"start_now") or state_time <= 0.0:
				_begin_combat()
		RunState.COMBAT:
			state_time -= delta
			spawn_time -= delta
			if spawn_time <= 0.0:
				_spawn_enemy()
				spawn_time = 1.45 if wave == 1 else 1.05
			if Input.is_action_just_pressed(&"skip_wave"):
				state_time = 0.0
			if state_time <= 0.0:
				_finish_wave()
		_:
			pass

	var display_time: float = maxf(0.0, state_time)
	hud.update_status(wave, _state_text(), display_time, player, vehicle, kills, relics)


func _begin_prepare() -> void:
	state = RunState.PREPARE
	state_time = PREPARE_DURATION
	spawn_time = 0.0
	player.controls_enabled = true
	hud.hide_overlay()
	_set_enemy_activity(false)


func _begin_combat() -> void:
	state = RunState.COMBAT
	state_time = WAVE_DURATION
	spawn_time = 0.2
	player.controls_enabled = true
	_set_enemy_activity(true)


func _finish_wave() -> void:
	_clear_enemies()
	player.controls_enabled = false
	if wave >= MAX_WAVE:
		state = RunState.VICTORY
		hud.show_end(true, kills, relics)
		return
	state = RunState.REWARD
	hud.show_relic_choices()


func _on_relic_selected(index: int) -> void:
	match index:
		0:
			player.damage_multiplier *= 1.25
			relics.append("増し弾")
		1:
			vehicle.apply_plating_relic()
			relics.append("補強板")
		2:
			player.repair_multiplier *= 1.5
			relics.append("高速修理")
	wave += 1
	_begin_prepare()


func _spawn_enemy() -> void:
	if get_tree().get_nodes_in_group(&"enemies").size() >= 32:
		return
	var kind: StringName = &"walker"
	var roll: float = rng.randf()
	if wave >= 2:
		if roll < 0.26:
			kind = &"climber"
		elif roll < 0.58:
			kind = &"runner"
	elif roll < 0.24:
		kind = &"runner"
	var side: int = -1 if rng.randf() < 0.48 else 1
	var enemy: EnemyUnit = EnemyScript.new() as EnemyUnit
	add_child(enemy)
	enemy.setup(kind, side, vehicle, player)
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: EnemyUnit) -> void:
	kills += 1


func _on_player_shoot(origin: Vector2, direction: Vector2, damage: float) -> void:
	if state != RunState.COMBAT:
		return
	var projectile: PlayerProjectile = ProjectileScript.new() as PlayerProjectile
	add_child(projectile)
	projectile.setup(origin, direction, damage)


func _on_vehicle_destroyed() -> void:
	if state in [RunState.VICTORY, RunState.DEFEAT]:
		return
	state = RunState.DEFEAT
	player.controls_enabled = false
	_set_enemy_activity(false)
	hud.show_end(false, kills, relics)


func _clear_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.queue_free()


func _set_enemy_activity(value: bool) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: EnemyUnit = node as EnemyUnit
		if enemy != null:
			enemy.active = value


func _state_text() -> String:
	match state:
		RunState.PREPARE:
			return "準備"
		RunState.COMBAT:
			return "走行戦闘"
		RunState.REWARD:
			return "報酬"
		RunState.VICTORY:
			return "勝利"
		RunState.DEFEAT:
			return "敗北"
	return ""


func _ensure_input_map() -> void:
	_add_key_action(&"move_left", [KEY_A, KEY_LEFT])
	_add_key_action(&"move_right", [KEY_D, KEY_RIGHT])
	_add_key_action(&"jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_key_action(&"drop_down", [KEY_S, KEY_DOWN])
	_add_key_action(&"interact", [KEY_E])
	_add_key_action(&"restart", [KEY_R])
	_add_key_action(&"start_now", [KEY_F1])
	_add_key_action(&"skip_wave", [KEY_F2])
	_add_mouse_action(&"fire_primary", MOUSE_BUTTON_LEFT)


func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode: int in keys:
		var event := InputEventKey.new()
		event.keycode = keycode as Key
		event.physical_keycode = keycode as Key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _add_mouse_action(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	# デバッグ短縮キーは埋め込みゲームでも確実に受け取れるよう直接処理する。
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_F1 and state == RunState.PREPARE:
		_begin_combat()
	elif key_event.keycode == KEY_F2 and state == RunState.COMBAT:
		state_time = 0.0
	elif key_event.keycode == KEY_R and state in [RunState.VICTORY, RunState.DEFEAT]:
		get_tree().reload_current_scene()


func _run_smoke_test() -> void:
	var failures: Array[String] = []
	await get_tree().process_frame

	# Wave開始と敵生成
	_begin_combat()
	if state != RunState.COMBAT or not is_equal_approx(state_time, WAVE_DURATION):
		failures.append("combat did not start")
	_spawn_enemy()
	await get_tree().process_frame
	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	if enemies.size() != 1:
		failures.append("enemy spawn count mismatch")
	else:
		var enemy: EnemyUnit = enemies[0] as EnemyUnit
		enemy.take_damage(9999.0)
		await get_tree().process_frame
		if kills != 1:
			failures.append("enemy kill was not counted")

	# 外装損傷と修理
	var front_before: float = float(vehicle.section_hp[&"front"])
	vehicle.take_attack(&"front", 50.0)
	if not is_equal_approx(float(vehicle.section_hp[&"front"]), front_before - 50.0):
		failures.append("vehicle damage mismatch")
	player.position = SurvivalVehicle.REPAIR_CONSOLE
	for step: int in range(30):
		vehicle.repair_at(player.position, 0.1, 1.0)
	if float(vehicle.section_hp[&"front"]) <= front_before - 50.0:
		failures.append("vehicle repair did not restore damage")

	# Wave1報酬とレリック適用
	_finish_wave()
	if state != RunState.REWARD:
		failures.append("wave 1 did not enter reward state")
	var old_max_hull: float = vehicle.max_hull
	_on_relic_selected(1)
	if wave != 2 or vehicle.max_hull <= old_max_hull or relics.size() != 1:
		failures.append("relic application mismatch")

	# Wave2仮勝利
	_begin_combat()
	_finish_wave()
	if state != RunState.VICTORY:
		failures.append("wave 2 did not enter victory state")

	if failures.is_empty():
		print("SMOKE_TEST_PASS wave=%d kills=%d hull=%.0f relic=%s" % [wave, kills, vehicle.hull, relics[0]])
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("SMOKE_TEST_FAIL: %s" % failure)
		get_tree().quit(1)
