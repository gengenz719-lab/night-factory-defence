class_name EnemyUnit
extends Node2D

signal died(enemy: EnemyUnit)
signal entered_vehicle(enemy: EnemyUnit)
signal module_attacked(instance_id: int)

const WALKER_TEXTURE: Texture2D = preload("res://assets/art/actors/enemy_walker.png")
const RUNNER_TEXTURE: Texture2D = preload("res://assets/art/actors/enemy_runner.png")
const CLIMBER_TEXTURE: Texture2D = preload("res://assets/art/actors/enemy_climber.png")
const CELL_SIZE_PX: float = 64.0
enum InvasionState { OUTSIDE, ENTERING, INSIDE }

var definition: EnemyDefinition
var enemy_type: StringName = &"enemy_walker"
var side: int = 1
var vehicle: VehicleState
var player: CrewPlayer
var players_by_peer: Dictionary = {}
var module_system: VehicleModuleSystem
var max_hp: float = 0.0
var hp: float = 0.0
var speed: float = 0.0
var player_damage: float = 0.0
var exterior_dps: float = 0.0
var attack_cooldown: float = 0.0
var active: bool = true
var inside_vehicle: bool = false
var _hit_flash: float = 0.0
var _sprite: Sprite2D
var net_id: int = 0
var replica_target_position: Vector2 = Vector2.ZERO
var is_network_replica: bool = false
var invasion_state: InvasionState = InvasionState.OUTSIDE
var entry_time: float = 0.0
var target_module: VehicleModuleState
var target_player: CrewPlayer
var target_evaluation_time: float = 0.0
var attack_section: StringName = &"front"


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.z_index = -1
	add_child(_sprite)
	_configure_sprite()


func setup(enemy_data: EnemyDefinition, spawn_side: int, target_vehicle: VehicleState, target_player: CrewPlayer, players: Dictionary = {}, modules: VehicleModuleSystem = null) -> void:
	definition = enemy_data
	enemy_type = definition.id
	side = spawn_side
	vehicle = target_vehicle
	player = target_player
	players_by_peer = players
	module_system = modules
	max_hp = definition.max_hp
	speed = definition.speed_cells_per_second * CELL_SIZE_PX
	player_damage = definition.player_damage
	exterior_dps = definition.exterior_dps
	hp = max_hp
	if enemy_type == &"enemy_climber":
		position = Vector2(-55.0 if side < 0 else 1655.0, 272.0)
	else:
		position = Vector2(-55.0 if side < 0 else 1655.0, 675.0)
	add_to_group(&"enemies")
	z_index = 24
	_configure_sprite()
	queue_redraw()


func _process(delta: float) -> void:
	if is_network_replica:
		position = position.lerp(replica_target_position, minf(1.0, delta / 0.1))
		queue_redraw()
		return
	if not active or vehicle == null or player == null:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if _sprite != null:
		_sprite.modulate = Color.WHITE if _hit_flash <= 0.0 else Color("#fff2d1")

	attack_section = &"roof" if enemy_type == &"enemy_climber" else &"front" if side < 0 else &"rear"
	if invasion_state == InvasionState.INSIDE:
		_handle_inside(delta)
	elif definition.can_invade and vehicle.is_breached(attack_section):
		_handle_breach_entry(delta)
	else:
		_handle_outside_attack(delta)
	queue_redraw()


func _handle_outside_attack(delta: float) -> void:
	var target_position: Vector2 = _outside_entry_position()
	position = position.move_toward(target_position, speed * delta)
	if position.distance_to(target_position) < definition.exterior_attack_range_px and attack_cooldown <= 0.0:
		vehicle.take_attack(attack_section, exterior_dps * definition.attack_interval_seconds)
		attack_cooldown = definition.attack_interval_seconds


func _handle_breach_entry(delta: float) -> void:
	var entry_position: Vector2 = _outside_entry_position()
	if invasion_state == InvasionState.OUTSIDE:
		position = position.move_toward(entry_position, speed * delta)
		if position.distance_to(entry_position) <= definition.exterior_attack_range_px + 8.0:
			invasion_state = InvasionState.ENTERING
			entry_time = definition.breach_entry_seconds
		return
	entry_time = maxf(0.0, entry_time - delta)
	if entry_time > 0.0:
		return
	invasion_state = InvasionState.INSIDE
	inside_vehicle = true
	position = _inside_entry_position()
	target_evaluation_time = 0.0
	entered_vehicle.emit(self)


func _handle_inside(delta: float) -> void:
	target_evaluation_time -= delta
	if target_evaluation_time <= 0.0:
		target_evaluation_time = definition.target_reevaluation_seconds
		_select_inside_target()
	var target_position: Vector2 = Vector2(SurvivalVehicle.LADDER_X, SurvivalVehicle.LOWER_FLOOR_Y - 25.0)
	if target_player != null:
		target_position = target_player.position
	elif target_module != null:
		target_position = module_system.grid_to_world(target_module.grid_position, target_module.definition.grid_size)
	position = position.move_toward(target_position, speed * delta)
	if position.distance_to(target_position) > definition.interior_attack_range_px or attack_cooldown > 0.0:
		return
	if target_player != null:
		target_player.take_damage(player_damage)
	elif target_module != null and module_system.damage_module(target_module, exterior_dps * definition.attack_interval_seconds):
		module_attacked.emit(target_module.instance_id)
	else:
		vehicle.take_attack(attack_section, exterior_dps * definition.attack_interval_seconds)
	attack_cooldown = definition.attack_interval_seconds


func _select_inside_target() -> void:
	target_player = null
	target_module = null
	var player_range: float = definition.interior_target_range_cells * CELL_SIZE_PX
	var closest_player_distance: float = player_range
	for peer_key: Variant in players_by_peer:
		var candidate := players_by_peer[peer_key] as CrewPlayer
		if candidate == null or candidate.survival.is_downed or candidate.survival.is_departed:
			continue
		var distance: float = position.distance_to(candidate.position)
		if distance <= closest_player_distance:
			closest_player_distance = distance
			target_player = candidate
	if target_player != null or module_system == null:
		return
	var closest_module_distance: float = INF
	for module: VehicleModuleState in module_system.modules.values():
		if module.hp <= 0.0:
			continue
		var is_priority_target: bool = module.is_operational() and (module.definition.tags.has(&"turret") or module.definition.tags.has(&"support"))
		var distance: float = position.distance_to(module_system.grid_to_world(module.grid_position, module.definition.grid_size))
		var current_is_priority: bool = target_module != null and target_module.is_operational() and (target_module.definition.tags.has(&"turret") or target_module.definition.tags.has(&"support"))
		if is_priority_target and (not current_is_priority or distance < closest_module_distance):
			target_module = module
			closest_module_distance = distance
		elif not current_is_priority and distance < closest_module_distance:
			target_module = module
			closest_module_distance = distance


func _outside_entry_position() -> Vector2:
	if attack_section == &"roof":
		return Vector2(SurvivalVehicle.LADDER_X, SurvivalVehicle.ROOF_FLOOR_Y - 15.0)
	return Vector2(SurvivalVehicle.LEFT_X - 26.0 if side < 0 else SurvivalVehicle.RIGHT_X + 26.0, SurvivalVehicle.LOWER_FLOOR_Y - 20.0)


func _inside_entry_position() -> Vector2:
	if attack_section == &"roof":
		return Vector2(SurvivalVehicle.LADDER_X, SurvivalVehicle.UPPER_FLOOR_Y - 24.0)
	return Vector2(SurvivalVehicle.LEFT_X + 38.0 if side < 0 else SurvivalVehicle.RIGHT_X - 38.0, SurvivalVehicle.LOWER_FLOOR_Y - 24.0)


func take_damage(amount: float) -> void:
	if is_network_replica:
		return
	if hp <= 0.0:
		return
	hp -= amount
	_hit_flash = 0.09
	if hp <= 0.0:
		died.emit(self)
		queue_free()
	else:
		queue_redraw()


func configure_network_replica(enemy_net_id: int) -> void:
	net_id = enemy_net_id
	is_network_replica = true
	active = false
	replica_target_position = position


func apply_network_snapshot(target_position: Vector2, health: float, entered_vehicle: bool, invasion_state_value: int, entry_time_value: float) -> void:
	replica_target_position = target_position
	hp = health
	inside_vehicle = entered_vehicle
	invasion_state = invasion_state_value as InvasionState
	entry_time = maxf(0.0, entry_time_value)


func _draw() -> void:
	# HPバー
	draw_rect(Rect2(-24, -68, 48, 5), Color("#241e25"), true)
	draw_rect(Rect2(-24, -68, 48.0 * clampf(hp / max_hp, 0.0, 1.0), 5), Color("#df5b57"), true)
	if invasion_state == InvasionState.ENTERING:
		draw_arc(Vector2.ZERO, 38.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - entry_time / maxf(0.01, definition.breach_entry_seconds)), 24, Color("#ffbd54"), 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(-40, -80), "侵入 %.1f" % entry_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _configure_sprite() -> void:
	if _sprite == null:
		return
	var texture: Texture2D = WALKER_TEXTURE
	var target_height: float = 98.0
	match enemy_type:
		&"enemy_runner":
			texture = RUNNER_TEXTURE
			target_height = 90.0
		&"enemy_climber":
			texture = CLIMBER_TEXTURE
			target_height = 110.0
	_sprite.texture = texture
	var sprite_scale: float = target_height / float(texture.get_height())
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.position = Vector2(0.0, 38.0 - target_height * 0.5)
	_sprite.flip_h = side > 0
