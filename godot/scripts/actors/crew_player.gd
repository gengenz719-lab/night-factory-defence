class_name CrewPlayer
extends Node2D

signal shoot_requested(origin: Vector2, direction: Vector2, damage: float)
signal health_changed

const BODY_TEXTURE: Texture2D = preload("res://assets/art/actors/crew_survivor.png")
const RIFLE_TEXTURE: Texture2D = preload("res://assets/art/actors/crew_rifle.png")
const HALF_HEIGHT: float = 23.0
const MOVE_SPEED: float = 250.0
const JUMP_SPEED: float = 520.0
const GRAVITY: float = 1450.0

var vehicle: SurvivalVehicle
var current_level: int = 0
var vertical_velocity: float = 0.0
var on_floor: bool = true
var controls_enabled: bool = true
var max_hp: float = 100.0
var hp: float = 100.0
var damage_multiplier: float = 1.0
var repair_multiplier: float = 1.0
var fire_cooldown: float = 0.0
var invulnerable_time: float = 0.0
var downed_time: float = 0.0
var is_downed: bool = false
var _climb_target_level: int = -1
var _is_repairing: bool = false
var aim_position: Vector2 = Vector2.RIGHT
var _body_sprite: Sprite2D
var _weapon_sprite: Sprite2D


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


func setup(target_vehicle: SurvivalVehicle) -> void:
	vehicle = target_vehicle
	position = Vector2(590, vehicle.floor_y(0) - HALF_HEIGHT)
	z_index = 30
	queue_redraw()


func _physics_process(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	aim_position = get_global_mouse_position()

	if is_downed:
		downed_time -= delta
		if downed_time <= 0.0:
			_respawn()
		_update_visuals()
		queue_redraw()
		return

	if not controls_enabled or vehicle == null:
		_update_visuals()
		queue_redraw()
		return

	_handle_climbing(delta)
	if _climb_target_level < 0:
		_handle_movement(delta)
	_handle_actions(delta)
	_update_visuals()
	queue_redraw()


func _handle_movement(delta: float) -> void:
	var axis: float = Input.get_axis(&"move_left", &"move_right")
	position.x += axis * MOVE_SPEED * delta
	# 短いタップでも動いたことが分かる最小ステップ。押し続け移動と併用する。
	if Input.is_action_just_pressed(&"move_left"):
		position.x -= 12.0
	if Input.is_action_just_pressed(&"move_right"):
		position.x += 12.0
	position.x = clampf(position.x, SurvivalVehicle.LEFT_X + 18.0, SurvivalVehicle.RIGHT_X - 18.0)

	if Input.is_action_just_pressed(&"jump") and on_floor:
		if absf(position.x - SurvivalVehicle.LADDER_X) < 54.0 and current_level < 2:
			_climb_target_level = current_level + 1
			on_floor = false
		else:
			vertical_velocity = -JUMP_SPEED
			on_floor = false

	if Input.is_action_just_pressed(&"drop_down") and on_floor:
		if absf(position.x - SurvivalVehicle.LADDER_X) < 54.0 and current_level > 0:
			_climb_target_level = current_level - 1
			on_floor = false

	if not on_floor:
		vertical_velocity += GRAVITY * delta
		position.y += vertical_velocity * delta
		var floor_center: float = vehicle.floor_y(current_level) - HALF_HEIGHT
		if vertical_velocity >= 0.0 and position.y >= floor_center:
			position.y = floor_center
			vertical_velocity = 0.0
			on_floor = true


func _handle_climbing(delta: float) -> void:
	if _climb_target_level < 0:
		return
	position.x = move_toward(position.x, SurvivalVehicle.LADDER_X, 300.0 * delta)
	var target_y: float = vehicle.floor_y(_climb_target_level) - HALF_HEIGHT
	position.y = move_toward(position.y, target_y, 245.0 * delta)
	if absf(position.y - target_y) < 1.0:
		position.y = target_y
		current_level = _climb_target_level
		_climb_target_level = -1
		on_floor = true


func _handle_actions(delta: float) -> void:
	_is_repairing = false
	if Input.is_action_just_pressed(&"interact"):
		# タップ時にも5HP相当の修理を行い、入力フィードバックを返す。
		_is_repairing = vehicle.repair_at(position, 0.25, repair_multiplier)
	elif Input.is_action_pressed(&"interact"):
		_is_repairing = vehicle.repair_at(position, delta, repair_multiplier)

	if Input.is_action_pressed(&"fire_primary") and fire_cooldown <= 0.0 and not _is_repairing:
		var direction: Vector2 = position.direction_to(aim_position)
		if direction.length_squared() > 0.1:
			shoot_requested.emit(position + direction * 38.0, direction, 15.0 * damage_multiplier)
			fire_cooldown = 0.25


func take_damage(amount: float) -> void:
	if invulnerable_time > 0.0 or is_downed:
		return
	hp = maxf(0.0, hp - amount)
	invulnerable_time = 0.7
	health_changed.emit()
	if hp <= 0.0:
		is_downed = true
		downed_time = 6.0
		controls_enabled = false


func _respawn() -> void:
	is_downed = false
	hp = max_hp * 0.5
	current_level = 0
	position = Vector2(590, vehicle.floor_y(0) - HALF_HEIGHT)
	controls_enabled = true
	invulnerable_time = 2.0
	health_changed.emit()


func _draw() -> void:
	if is_downed:
		draw_circle(Vector2.ZERO, 18.0, Color("#7b3441"))
		draw_string(ThemeDB.fallback_font, Vector2(-34, -30), "DOWN %.0f" % downed_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return

	if _is_repairing:
		draw_arc(Vector2.ZERO, 30.0, -PI * 0.7, PI * 0.7, 20, Color("#5ff0ce"), 3.0)


func _update_visuals() -> void:
	if _body_sprite == null or _weapon_sprite == null:
		return
	_body_sprite.visible = not is_downed
	_weapon_sprite.visible = not is_downed
	if is_downed:
		return
	var local_aim: Vector2 = (aim_position - global_position).normalized()
	if local_aim.length_squared() < 0.1:
		local_aim = Vector2.RIGHT
	_body_sprite.flip_h = local_aim.x < 0.0
	_weapon_sprite.position = local_aim * 17.0 + Vector2(0.0, -2.0)
	_weapon_sprite.rotation = local_aim.angle()
	_weapon_sprite.flip_v = local_aim.x < 0.0
	var flash_color: Color = Color("#d8f7ff") if invulnerable_time > 0.0 else Color.WHITE
	_body_sprite.modulate = flash_color
	_weapon_sprite.modulate = flash_color
