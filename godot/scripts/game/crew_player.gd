class_name CrewPlayer
extends Node2D

signal health_changed

const BODY_TEXTURE: Texture2D = preload("res://assets/art/actors/crew_survivor.png")
const RIFLE_TEXTURE: Texture2D = preload("res://assets/art/actors/crew_rifle.png")
const HALF_HEIGHT: float = 23.0
const CELL_SIZE_PX: float = 64.0

var vehicle: VehicleState
var definition: CharacterDefinition
var weapon_definition: WeaponDefinition
var current_level: int = 0
var vertical_velocity: float = 0.0
var on_floor: bool = true
var controls_enabled: bool = true
var damage_multiplier: float = 1.0
var repair_multiplier: float = 1.0
var fire_cooldown: float = 0.0
var survival := PlayerSurvivalState.new()
var dodge_visual_time: float = 0.0
var _climb_target_level: int = -1
var _is_repairing: bool = false
var aim_position: Vector2 = Vector2.RIGHT
var _body_sprite: Sprite2D
var _weapon_sprite: Sprite2D
var network_controlled: bool = false
var peer_id: int = 1
var replica_target_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_body_sprite = Sprite2D.new()
	_body_sprite.texture = BODY_TEXTURE
	var body_scale: float = 90.0 / float(BODY_TEXTURE.get_height())
	_body_sprite.scale = Vector2(body_scale, body_scale)
	_body_sprite.position = Vector2(0.0, HALF_HEIGHT - 45.0)
	_body_sprite.z_index = -1
	add_child(_body_sprite)

	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.texture = RIFLE_TEXTURE
	var weapon_scale: float = 58.0 / float(RIFLE_TEXTURE.get_width())
	_weapon_sprite.scale = Vector2(weapon_scale, weapon_scale)
	_weapon_sprite.z_index = 1
	add_child(_weapon_sprite)
	_update_visuals()


func setup(target_vehicle: VehicleState, character_data: CharacterDefinition, weapon_data: WeaponDefinition) -> void:
	vehicle = target_vehicle
	definition = character_data
	weapon_definition = weapon_data
	survival.setup(definition)
	survival.downed.connect(_on_downed)
	survival.departed.connect(_on_departed)
	survival.revived.connect(_on_revived)
	survival.returned.connect(_on_returned)
	repair_multiplier = definition.repair_speed_multiplier
	position = Vector2(590, vehicle.floor_y(0) - HALF_HEIGHT)
	z_index = 30
	queue_redraw()


func _physics_process(delta: float) -> void:
	if peer_id != NetworkSession.local_peer_id():
		position = position.lerp(replica_target_position, minf(1.0, delta / 0.1))
	_update_visuals()
	queue_redraw()


func _handle_climbing(delta: float) -> void:
	if _climb_target_level < 0:
		return
	position.x = move_toward(position.x, SurvivalVehicle.LADDER_X, definition.climb_horizontal_speed_px * delta)
	var target_y: float = vehicle.floor_y(_climb_target_level) - HALF_HEIGHT
	position.y = move_toward(position.y, target_y, definition.climb_vertical_speed_px * delta)
	if absf(position.y - target_y) < 1.0:
		position.y = target_y
		current_level = _climb_target_level
		_climb_target_level = -1
		on_floor = true


func apply_network_input(axis: Vector2, aim: Vector2, delta: float, wants_interact: bool) -> void:
	if survival.is_downed or survival.is_departed or not controls_enabled:
		return
	var safe_axis: Vector2 = axis.limit_length(1.0)
	if _climb_target_level >= 0:
		_handle_climbing(delta)
	else:
		position.x += safe_axis.x * definition.move_speed_cells_per_second * CELL_SIZE_PX * delta
		_handle_network_vertical(safe_axis.y, delta)
	position.x = clampf(position.x, SurvivalVehicle.LEFT_X + 18.0, SurvivalVehicle.RIGHT_X - 18.0)
	aim_position = position + (aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT) * 200.0
	_is_repairing = wants_interact


func _handle_network_vertical(vertical_axis: float, delta: float) -> void:
	if vertical_axis < -0.5 and on_floor:
		if absf(position.x - SurvivalVehicle.LADDER_X) < 54.0 and current_level < 2:
			_climb_target_level = current_level + 1
			on_floor = false
		else:
			vertical_velocity = -sqrt(2.0 * definition.gravity_px * definition.jump_height_cells * CELL_SIZE_PX)
			on_floor = false
	elif vertical_axis > 0.5 and on_floor and absf(position.x - SurvivalVehicle.LADDER_X) < 54.0 and current_level > 0:
		_climb_target_level = current_level - 1
		on_floor = false
	if not on_floor and _climb_target_level < 0:
		vertical_velocity += definition.gravity_px * delta
		position.y += vertical_velocity * delta
		var floor_center: float = vehicle.floor_y(current_level) - HALF_HEIGHT
		if vertical_velocity >= 0.0 and position.y >= floor_center:
			position.y = floor_center
			vertical_velocity = 0.0
			on_floor = true


func apply_prediction_motion(axis: Vector2, delta: float) -> void:
	position.x += axis.limit_length(1.0).x * definition.move_speed_cells_per_second * CELL_SIZE_PX * delta
	position.x = clampf(position.x, SurvivalVehicle.LEFT_X + 18.0, SurvivalVehicle.RIGHT_X - 18.0)


func consume_fire_request() -> bool:
	if fire_cooldown > 0.0 or survival.is_downed or survival.is_departed or not controls_enabled or _is_repairing:
		return false
	fire_cooldown = 1.0 / weapon_definition.shots_per_second
	return true


func apply_network_snapshot(
	authoritative_position: Vector2,
	aim: Vector2,
	health: float,
	downed: bool,
	departed: bool,
	invulnerability: float,
	dodge_cooldown_value: float,
	down_time: float,
	return_time_value: float,
	revive_progress_value: float
) -> void:
	survival.apply_snapshot(
		health, downed, departed, invulnerability, dodge_cooldown_value,
		down_time, return_time_value, revive_progress_value
	)
	if invulnerability > 0.0 and dodge_cooldown_value > 0.0:
		dodge_visual_time = maxf(dodge_visual_time, invulnerability)
	aim_position = authoritative_position + aim.normalized() * 200.0
	if peer_id == NetworkSession.local_peer_id():
		position = authoritative_position
	else:
		replica_target_position = authoritative_position


func take_damage(amount: float) -> void:
	if survival.take_damage(amount):
		if not survival.is_downed:
			survival.invulnerable_time = definition.damage_invulnerability_seconds
		health_changed.emit()


func authority_tick(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	dodge_visual_time = maxf(0.0, dodge_visual_time - delta)
	survival.authority_tick(delta)


func authority_request_dodge(axis: Vector2, aim: Vector2) -> bool:
	if not controls_enabled or not survival.try_dodge():
		return false
	var direction_x: float = axis.x
	if absf(direction_x) < 0.1:
		direction_x = aim.x
	if absf(direction_x) < 0.1:
		direction_x = 1.0
	position.x += signf(direction_x) * definition.dodge_distance_cells * CELL_SIZE_PX
	position.x = clampf(position.x, SurvivalVehicle.LEFT_X + 18.0, SurvivalVehicle.RIGHT_X - 18.0)
	dodge_visual_time = definition.dodge_invulnerability_seconds
	return true


func authority_add_revive_progress(delta: float) -> bool:
	return survival.add_revive_progress(delta)


func _on_downed() -> void:
	controls_enabled = false
	health_changed.emit()


func _on_departed() -> void:
	controls_enabled = false
	health_changed.emit()


func _on_revived() -> void:
	controls_enabled = true
	health_changed.emit()


func _on_returned() -> void:
	current_level = 0
	position = Vector2(SurvivalVehicle.REPAIR_CONSOLE.x, vehicle.floor_y(0) - HALF_HEIGHT)
	replica_target_position = position
	controls_enabled = true
	health_changed.emit()


func apply_relic(relic: RelicDefinition) -> void:
	damage_multiplier *= relic.weapon_damage_multiplier
	if relic.wave_end_player_heal > 0.0:
		survival.hp = minf(survival.max_hp, survival.hp + relic.wave_end_player_heal)
		health_changed.emit()


func _draw() -> void:
	if survival.is_departed:
		draw_string(ThemeDB.fallback_font, Vector2(-42, -30), "RETURN %.0f" % survival.return_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return
	if survival.is_downed:
		draw_circle(Vector2.ZERO, 18.0, Color("#7b3441"))
		draw_arc(Vector2.ZERO, 25.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(survival.revive_progress / definition.revive_seconds, 0.0, 1.0), 20, Color("#78f0d2"), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-34, -30), "DOWN %.0f" % survival.downed_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return

	if _is_repairing:
		draw_arc(Vector2.ZERO, 30.0, -PI * 0.7, PI * 0.7, 20, Color("#5ff0ce"), 3.0)


func _update_visuals() -> void:
	if _body_sprite == null or _weapon_sprite == null:
		return
	_body_sprite.visible = not survival.is_downed and not survival.is_departed
	_weapon_sprite.visible = not survival.is_downed and not survival.is_departed
	if survival.is_downed or survival.is_departed:
		return
	var local_aim: Vector2 = (aim_position - global_position).normalized()
	if local_aim.length_squared() < 0.1:
		local_aim = Vector2.RIGHT
	_body_sprite.flip_h = local_aim.x < 0.0
	_weapon_sprite.position = local_aim * 17.0 + Vector2(0.0, -2.0)
	_weapon_sprite.rotation = local_aim.angle()
	_weapon_sprite.flip_v = local_aim.x < 0.0
	var flash_color: Color = Color("#78f0d2") if dodge_visual_time > 0.0 else Color("#d8f7ff") if survival.invulnerable_time > 0.0 else Color.WHITE
	_body_sprite.modulate = flash_color
	_weapon_sprite.modulate = flash_color
