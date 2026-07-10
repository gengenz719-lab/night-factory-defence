class_name EnemyUnit
extends Node2D

signal died(enemy: EnemyUnit)

var enemy_type: StringName = &"walker"
var side: int = 1
var vehicle: SurvivalVehicle
var player: CrewPlayer
var max_hp: float = 40.0
var hp: float = 40.0
var speed: float = 78.0
var player_damage: float = 8.0
var vehicle_damage: float = 7.0
var attack_cooldown: float = 0.0
var active: bool = true
var inside_vehicle: bool = false
var _hit_flash: float = 0.0


func setup(kind: StringName, spawn_side: int, target_vehicle: SurvivalVehicle, target_player: CrewPlayer) -> void:
	enemy_type = kind
	side = spawn_side
	vehicle = target_vehicle
	player = target_player
	match enemy_type:
		&"runner":
			max_hp = 32.0
			speed = 150.0
			player_damage = 7.0
			vehicle_damage = 6.0
		&"climber":
			max_hp = 55.0
			speed = 105.0
			player_damage = 10.0
			vehicle_damage = 8.0
		_:
			max_hp = 40.0
			speed = 76.0
			player_damage = 8.0
			vehicle_damage = 7.0
	hp = max_hp
	if enemy_type == &"climber":
		position = Vector2(-55.0 if side < 0 else 1655.0, 272.0)
	else:
		position = Vector2(-55.0 if side < 0 else 1655.0, 675.0)
	add_to_group(&"enemies")
	z_index = 24
	queue_redraw()


func _process(delta: float) -> void:
	if not active or vehicle == null or player == null:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)

	var section: StringName = &"roof" if enemy_type == &"climber" else &"front" if side < 0 else &"rear"
	if not inside_vehicle and vehicle.is_breached(section) and enemy_type != &"climber":
		inside_vehicle = true

	if inside_vehicle:
		var target: Vector2 = player.position if not player.is_downed else Vector2(SurvivalVehicle.LADDER_X, SurvivalVehicle.LOWER_FLOOR_Y - 25.0)
		position = position.move_toward(target, speed * delta)
		if position.distance_to(target) < 44.0 and attack_cooldown <= 0.0:
			if player.is_downed:
				vehicle.take_attack(section, vehicle_damage)
			else:
				player.take_damage(player_damage)
				# 侵入者はクルーと戦いながら車内設備・配線も少しずつ破壊する。
				vehicle.take_attack(section, vehicle_damage * 0.12)
			attack_cooldown = 0.9
	else:
		var target_x: float = SurvivalVehicle.LEFT_X - 26.0 if side < 0 else SurvivalVehicle.RIGHT_X + 26.0
		var target_y: float = 285.0 if enemy_type == &"climber" else 675.0
		var target_position: Vector2 = Vector2(target_x, target_y)
		position = position.move_toward(target_position, speed * delta)
		if position.distance_to(target_position) < 18.0 and attack_cooldown <= 0.0:
			vehicle.take_attack(section, vehicle_damage)
			attack_cooldown = 0.75
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_hit_flash = 0.09
	if hp <= 0.0:
		died.emit(self)
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var base_color: Color
	match enemy_type:
		&"runner":
			base_color = Color("#b9cf4a")
		&"climber":
			base_color = Color("#b46981")
		_:
			base_color = Color("#699955")
	if _hit_flash > 0.0:
		base_color = Color.WHITE

	if enemy_type == &"climber":
		draw_circle(Vector2.ZERO, 15.0, base_color)
		for angle: float in [-2.5, -1.6, -0.6, 0.6, 1.6, 2.5]:
			var end: Vector2 = Vector2.from_angle(angle) * 28.0
			draw_line(Vector2.ZERO, end, Color("#4b2837"), 5.0)
	else:
		draw_circle(Vector2(0, -24), 12.0, Color("#a8ad7a"))
		draw_rect(Rect2(-13, -13, 26, 38), base_color, true)
		var lean: float = -8.0 if side < 0 else 8.0
		draw_line(Vector2(-8, 24), Vector2(-13 + lean, 38), Color("#32372f"), 6.0)
		draw_line(Vector2(8, 24), Vector2(13 + lean, 38), Color("#32372f"), 6.0)

	# HPバー
	draw_rect(Rect2(-22, -48, 44, 5), Color("#241e25"), true)
	draw_rect(Rect2(-22, -48, 44.0 * clampf(hp / max_hp, 0.0, 1.0), 5), Color("#df5b57"), true)
