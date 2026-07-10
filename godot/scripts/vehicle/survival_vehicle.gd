class_name SurvivalVehicle
extends Node2D

signal destroyed
signal values_changed

const LEFT_X: float = 360.0
const RIGHT_X: float = 1240.0
const TOP_Y: float = 300.0
const BOTTOM_Y: float = 690.0
const LOWER_FLOOR_Y: float = 650.0
const UPPER_FLOOR_Y: float = 500.0
const ROOF_FLOOR_Y: float = 300.0
const LADDER_X: float = 800.0
const REPAIR_CONSOLE: Vector2 = Vector2(600, 610)

var max_hull: float = 1000.0
var hull: float = 1000.0
var max_section_hp: Dictionary = {
	&"front": 300.0,
	&"rear": 250.0,
	&"roof": 220.0,
	&"lower": 220.0,
}
var section_hp: Dictionary = {}
var supplies: float = 100.0
var repair_multiplier: float = 1.0
var _repair_supply_progress: float = 0.0
var _damage_flash: float = 0.0


func _ready() -> void:
	for key: StringName in max_section_hp:
		section_hp[key] = max_section_hp[key]
	z_index = 10
	queue_redraw()


func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta)
	queue_redraw()


func floor_y(level: int) -> float:
	match level:
		1:
			return UPPER_FLOOR_Y
		2:
			return ROOF_FLOOR_Y
		_:
			return LOWER_FLOOR_Y


func is_breached(section: StringName) -> bool:
	return float(section_hp.get(section, 0.0)) <= 0.0


func take_attack(section: StringName, amount: float) -> void:
	if hull <= 0.0:
		return
	var remaining: float = amount
	var current_section: float = float(section_hp.get(section, 0.0))
	if current_section > 0.0:
		var absorbed: float = minf(current_section, remaining)
		section_hp[section] = current_section - absorbed
		remaining -= absorbed
	if remaining > 0.0:
		hull = maxf(0.0, hull - remaining)
	_damage_flash = 0.12
	values_changed.emit()
	if hull <= 0.0:
		destroyed.emit()


func repair_at(player_position: Vector2, delta: float, player_multiplier: float) -> bool:
	if player_position.distance_to(REPAIR_CONSOLE) > 95.0 or supplies < 1.0:
		return false
	var target: StringName = _lowest_damaged_section()
	var heal_per_second: float = 20.0 * repair_multiplier * player_multiplier
	var heal: float = heal_per_second * delta
	if target != &"":
		section_hp[target] = minf(float(max_section_hp[target]), float(section_hp[target]) + heal)
	elif hull < max_hull:
		hull = minf(max_hull, hull + heal * 0.8)
	else:
		return false

	_repair_supply_progress += heal / 10.0
	while _repair_supply_progress >= 1.0 and supplies >= 1.0:
		_repair_supply_progress -= 1.0
		supplies -= 1.0
	values_changed.emit()
	return true


func apply_plating_relic() -> void:
	max_hull += 200.0
	# テスト版では車体も即時回復し、選択結果をすぐ体感できるようにする。
	hull = minf(max_hull, hull + 200.0)
	for key: StringName in max_section_hp:
		var bonus: float = float(max_section_hp[key]) * 0.20
		max_section_hp[key] = float(max_section_hp[key]) + bonus
		section_hp[key] = minf(float(max_section_hp[key]), float(section_hp[key]) + bonus)
	values_changed.emit()


func _lowest_damaged_section() -> StringName:
	var result: StringName = &""
	var lowest_ratio: float = 1.01
	for key: StringName in max_section_hp:
		var ratio: float = float(section_hp[key]) / float(max_section_hp[key])
		if ratio < 1.0 and ratio < lowest_ratio:
			lowest_ratio = ratio
			result = key
	return result


func section_ratio(section: StringName) -> float:
	return float(section_hp.get(section, 0.0)) / float(max_section_hp.get(section, 1.0))


func _draw() -> void:
	var flash_color: Color = Color("#8f3b35") if _damage_flash > 0.0 else Color("#252a31")
	# 車体外形
	draw_rect(Rect2(LEFT_X - 34, TOP_Y - 28, RIGHT_X - LEFT_X + 68, BOTTOM_Y - TOP_Y + 50), flash_color, true)
	draw_rect(Rect2(LEFT_X, TOP_Y, RIGHT_X - LEFT_X, BOTTOM_Y - TOP_Y), Color("#15191f"), true)

	# 車内の暖色区画
	draw_rect(Rect2(LEFT_X + 18, TOP_Y + 24, RIGHT_X - LEFT_X - 36, 176), Color("#433127"), true)
	draw_rect(Rect2(LEFT_X + 18, UPPER_FLOOR_Y + 16, RIGHT_X - LEFT_X - 36, 132), Color("#302b28"), true)
	draw_rect(Rect2(LEFT_X + 18, TOP_Y + 24, RIGHT_X - LEFT_X - 36, 176), Color("#b8793f"), false, 3.0)
	draw_rect(Rect2(LEFT_X + 18, UPPER_FLOOR_Y + 16, RIGHT_X - LEFT_X - 36, 132), Color("#b8793f"), false, 3.0)

	# 床
	draw_rect(Rect2(LEFT_X - 8, UPPER_FLOOR_Y, RIGHT_X - LEFT_X + 16, 14), Color("#77716b"), true)
	draw_rect(Rect2(LEFT_X - 8, LOWER_FLOOR_Y, RIGHT_X - LEFT_X + 16, 18), Color("#77716b"), true)

	# はしご
	for y: int in range(330, 646, 28):
		draw_line(Vector2(LADDER_X - 22, y), Vector2(LADDER_X + 22, y), Color("#d09a55"), 4.0)
	draw_line(Vector2(LADDER_X - 22, 320), Vector2(LADDER_X - 22, 650), Color("#9a7448"), 5.0)
	draw_line(Vector2(LADDER_X + 22, 320), Vector2(LADDER_X + 22, 650), Color("#9a7448"), 5.0)

	# 操縦席、工作台、ソファ、発電機
	draw_rect(Rect2(LEFT_X + 38, 565, 120, 72), Color("#263843"), true)
	draw_rect(Rect2(LEFT_X + 44, 578, 48, 26), Color("#78b7c7"), true)
	draw_rect(Rect2(540, 575, 126, 62), Color("#4d3b2d"), true)
	draw_rect(Rect2(552, 560, 102, 16), Color("#c48a4c"), true)
	draw_circle(REPAIR_CONSOLE, 16.0, Color("#55d6be"))
	draw_rect(Rect2(920, 570, 168, 56), Color("#365a5b"), true)
	draw_rect(Rect2(1090, 540, 98, 96), Color("#67452f"), true)
	for i: int in range(3):
		draw_circle(Vector2(1116 + i * 25, 570), 8.0, Color("#f3b45e"))

	# 射撃窓
	draw_rect(Rect2(LEFT_X - 16, 390, 34, 68), Color("#8bc5cf"), true)
	draw_rect(Rect2(RIGHT_X - 18, 390, 34, 68), Color("#8bc5cf"), true)

	# 車輪
	for wheel_x: float in [LEFT_X + 150.0, RIGHT_X - 150.0]:
		draw_circle(Vector2(wheel_x, BOTTOM_Y + 35), 58.0, Color("#111318"))
		draw_circle(Vector2(wheel_x, BOTTOM_Y + 35), 29.0, Color("#6a6259"))
		draw_circle(Vector2(wheel_x, BOTTOM_Y + 35), 10.0, Color("#c18b4f"))

	# 方向別外装の状態色
	_draw_section_bar(Vector2(LEFT_X - 32, 320), Vector2(12, 170), section_ratio(&"front"))
	_draw_section_bar(Vector2(RIGHT_X + 20, 320), Vector2(12, 170), section_ratio(&"rear"))
	_draw_section_bar(Vector2(650, TOP_Y - 22), Vector2(300, 10), section_ratio(&"roof"))
	_draw_section_bar(Vector2(650, BOTTOM_Y + 8), Vector2(300, 10), section_ratio(&"lower"))

	# 修理可能地点の表示
	draw_arc(REPAIR_CONSOLE, 24.0, 0.0, TAU, 24, Color("#78f0d2"), 2.0)


func _draw_section_bar(pos: Vector2, size: Vector2, ratio: float) -> void:
	draw_rect(Rect2(pos, size), Color("#252129"), true)
	var color: Color = Color("#65c466") if ratio > 0.5 else Color("#e0a64c") if ratio > 0.0 else Color("#e34f4f")
	if size.x > size.y:
		draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), color, true)
	else:
		var filled: float = size.y * clampf(ratio, 0.0, 1.0)
		draw_rect(Rect2(pos + Vector2(0, size.y - filled), Vector2(size.x, filled)), color, true)
