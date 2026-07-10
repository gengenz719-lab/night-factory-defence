class_name PlayerProjectile
extends Node2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 15.0
var lifetime: float = 2.2


func setup(origin: Vector2, direction: Vector2, shot_damage: float) -> void:
	position = origin
	velocity = direction.normalized() * 860.0
	damage = shot_damage
	z_index = 40
	queue_redraw()


func _process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: EnemyUnit = node as EnemyUnit
		if enemy != null and is_instance_valid(enemy) and position.distance_to(enemy.position) < 25.0:
			enemy.take_damage(damage)
			queue_free()
			return
	if lifetime <= 0.0 or position.x < -100.0 or position.x > 1700.0 or position.y < -100.0 or position.y > 1000.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color("#fff0a8"))
	draw_line(Vector2.ZERO, -velocity.normalized() * 18.0, Color("#f0a34d"), 3.0)
