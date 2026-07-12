class_name SpikePooledVisual
extends Sprite2D

## 敵と弾で共用する軽量表示ノード。非表示化して再利用し、生成・破棄を行わない。

enum VisualKind { ENEMY, PLAYER_BULLET, VEHICLE_BULLET, ENEMY_BULLET }

const VIEW_SIZE := Vector2(1920.0, 1080.0)

var kind: VisualKind = VisualKind.ENEMY
var pool_index: int = 0
var velocity: Vector2 = Vector2.ZERO
var base_y: float = 0.0
var animation_phase: float = 0.0
var reuse_count: int = 0


func configure(visual_kind: VisualKind, index: int, visual_texture: Texture2D, tint: Color) -> void:
	kind = visual_kind
	pool_index = index
	texture = visual_texture
	modulate = tint
	centered = true
	set_active(false)


func set_active(value: bool) -> void:
	visible = value
	set_process(value)
	if value:
		_reset_motion()


func _process(delta: float) -> void:
	animation_phase += delta
	position += velocity * delta
	if kind == VisualKind.ENEMY:
		position.y = base_y + sin(animation_phase * 5.0 + float(pool_index)) * 10.0
		var pulse: float = 1.0 + sin(animation_phase * 7.0 + float(pool_index) * 0.37) * 0.08
		scale = Vector2(pulse, 2.0 - pulse)
		self_modulate.a = 0.78 + sin(animation_phase * 9.0 + float(pool_index)) * 0.18
	else:
		rotation = velocity.angle()
		self_modulate.a = 0.82 + sin(animation_phase * 18.0 + float(pool_index)) * 0.16
	if position.x < -80.0 or position.x > VIEW_SIZE.x + 80.0 or position.y < -80.0 or position.y > VIEW_SIZE.y + 80.0:
		reuse_count += 1
		_reset_motion()


func _reset_motion() -> void:
	animation_phase = float(pool_index) * 0.17
	match kind:
		VisualKind.ENEMY:
			position = Vector2(2020.0 + float(pool_index % 12) * 86.0, 500.0 + float(pool_index % 6) * 72.0)
			base_y = position.y
			velocity = Vector2(-120.0 - float(pool_index % 7) * 18.0, 0.0)
			scale = Vector2.ONE
		VisualKind.PLAYER_BULLET:
			position = Vector2(420.0 + float(pool_index % 8) * 26.0, 470.0 + float(pool_index % 12) * 28.0)
			velocity = Vector2(720.0 + float(pool_index % 5) * 35.0, -80.0 + float(pool_index % 7) * 24.0)
		VisualKind.VEHICLE_BULLET:
			position = Vector2(840.0, 410.0 + float(pool_index % 10) * 24.0)
			velocity = Vector2(900.0 + float(pool_index % 6) * 40.0, -120.0 + float(pool_index % 9) * 30.0)
		VisualKind.ENEMY_BULLET:
			position = Vector2(1880.0 - float(pool_index % 10) * 24.0, 300.0 + float(pool_index % 14) * 36.0)
			velocity = Vector2(-520.0 - float(pool_index % 5) * 30.0, -70.0 + float(pool_index % 8) * 22.0)
