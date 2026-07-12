class_name SpikeVisualPool
extends Node

## 最大負荷分を起動時に確保し、段階計測では表示数だけを切り替える。

const MAX_ENEMIES: int = 60
const MAX_PLAYER_BULLETS: int = 80
const MAX_VEHICLE_BULLETS: int = 80
const MAX_ENEMY_BULLETS: int = 60

var enemy_pool: Array[SpikePooledVisual] = []
var player_bullet_pool: Array[SpikePooledVisual] = []
var vehicle_bullet_pool: Array[SpikePooledVisual] = []
var enemy_bullet_pool: Array[SpikePooledVisual] = []


func setup(world: Node2D, enemy_texture: Texture2D, bullet_texture: Texture2D) -> void:
	enemy_pool = _create_pool(world, SpikePooledVisual.VisualKind.ENEMY, MAX_ENEMIES, enemy_texture, Color("#9dd36f"))
	player_bullet_pool = _create_pool(world, SpikePooledVisual.VisualKind.PLAYER_BULLET, MAX_PLAYER_BULLETS, bullet_texture, Color("#72e6ff"))
	vehicle_bullet_pool = _create_pool(world, SpikePooledVisual.VisualKind.VEHICLE_BULLET, MAX_VEHICLE_BULLETS, bullet_texture, Color("#ffd166"))
	enemy_bullet_pool = _create_pool(world, SpikePooledVisual.VisualKind.ENEMY_BULLET, MAX_ENEMY_BULLETS, bullet_texture, Color("#ff6b7a"))


func set_active_counts(enemy_count: int, player_bullets: int, vehicle_bullets: int, enemy_bullets: int) -> void:
	_set_pool_count(enemy_pool, enemy_count)
	_set_pool_count(player_bullet_pool, player_bullets)
	_set_pool_count(vehicle_bullet_pool, vehicle_bullets)
	_set_pool_count(enemy_bullet_pool, enemy_bullets)


func active_visual_count() -> int:
	return _visible_count(enemy_pool) + _visible_count(player_bullet_pool) + _visible_count(vehicle_bullet_pool) + _visible_count(enemy_bullet_pool)


func total_reuses() -> int:
	var result: int = 0
	for pool: Array[SpikePooledVisual] in [enemy_pool, player_bullet_pool, vehicle_bullet_pool, enemy_bullet_pool]:
		for visual: SpikePooledVisual in pool:
			result += visual.reuse_count
	return result


func _create_pool(world: Node2D, kind: SpikePooledVisual.VisualKind, capacity: int, visual_texture: Texture2D, tint: Color) -> Array[SpikePooledVisual]:
	var result: Array[SpikePooledVisual] = []
	for index: int in capacity:
		var visual := SpikePooledVisual.new()
		world.add_child(visual)
		visual.configure(kind, index, visual_texture, tint)
		result.append(visual)
	return result


func _set_pool_count(pool: Array[SpikePooledVisual], count: int) -> void:
	for index: int in pool.size():
		pool[index].set_active(index < count)


func _visible_count(pool: Array[SpikePooledVisual]) -> int:
	var result: int = 0
	for visual: SpikePooledVisual in pool:
		if visual.visible:
			result += 1
	return result
