class_name EnemyUnit
extends Node2D

signal died(enemy: EnemyUnit)

const WALKER_TEXTURE: Texture2D = preload("res://assets/art/actors/enemy_walker.png")
const RUNNER_TEXTURE: Texture2D = preload("res://assets/art/actors/enemy_runner.png")
const CLIMBER_TEXTURE: Texture2D = preload("res://assets/art/actors/enemy_climber.png")
const CELL_SIZE_PX: float = 64.0

var definition: EnemyDefinition
var enemy_type: StringName = &"enemy_walker"
var side: int = 1
var vehicle: VehicleState
var player: CrewPlayer
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


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.z_index = -1
	add_child(_sprite)
	_configure_sprite()


func setup(enemy_data: EnemyDefinition, spawn_side: int, target_vehicle: VehicleState, target_player: CrewPlayer) -> void:
	definition = enemy_data
	enemy_type = definition.id
	side = spawn_side
	vehicle = target_vehicle
	player = target_player
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

	var section: StringName = &"roof" if enemy_type == &"enemy_climber" else &"front" if side < 0 else &"rear"
	if not inside_vehicle and vehicle.is_breached(section) and enemy_type != &"enemy_climber":
		inside_vehicle = true

	if inside_vehicle:
		var target: Vector2 = player.position if not player.is_downed else Vector2(SurvivalVehicle.LADDER_X, SurvivalVehicle.LOWER_FLOOR_Y - 25.0)
		position = position.move_toward(target, speed * delta)
		if position.distance_to(target) < definition.interior_attack_range_px and attack_cooldown <= 0.0:
			if player.is_downed:
				vehicle.take_attack(section, exterior_dps * definition.attack_interval_seconds)
			else:
				player.take_damage(player_damage)
				# 侵入者はクルーと戦いながら車内設備・配線も少しずつ破壊する。
				vehicle.take_attack(section, exterior_dps * definition.attack_interval_seconds * definition.interior_vehicle_damage_ratio)
			attack_cooldown = definition.attack_interval_seconds
	else:
		var target_x: float = SurvivalVehicle.LEFT_X - 26.0 if side < 0 else SurvivalVehicle.RIGHT_X + 26.0
		var target_y: float = 285.0 if enemy_type == &"enemy_climber" else 675.0
		var target_position: Vector2 = Vector2(target_x, target_y)
		position = position.move_toward(target_position, speed * delta)
		if position.distance_to(target_position) < definition.exterior_attack_range_px and attack_cooldown <= 0.0:
			vehicle.take_attack(section, exterior_dps * definition.attack_interval_seconds)
			attack_cooldown = definition.attack_interval_seconds
	queue_redraw()


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


func apply_network_snapshot(target_position: Vector2, health: float, entered_vehicle: bool) -> void:
	replica_target_position = target_position
	hp = health
	inside_vehicle = entered_vehicle


func _draw() -> void:
	# HPバー
	draw_rect(Rect2(-24, -68, 48, 5), Color("#241e25"), true)
	draw_rect(Rect2(-24, -68, 48.0 * clampf(hp / max_hp, 0.0, 1.0), 5), Color("#df5b57"), true)


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
