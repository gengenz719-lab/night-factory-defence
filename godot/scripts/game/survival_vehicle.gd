class_name SurvivalVehicle
extends Node2D

const VEHICLE_TEXTURE: Texture2D = preload("res://assets/art/vehicle/survival_vehicle.png")
const LEFT_X: float = 360.0
const RIGHT_X: float = 1240.0
const TOP_Y: float = 300.0
const BOTTOM_Y: float = 690.0
const LOWER_FLOOR_Y: float = 650.0
const UPPER_FLOOR_Y: float = 500.0
const ROOF_FLOOR_Y: float = 300.0
const LADDER_X: float = 800.0
const REPAIR_CONSOLE: Vector2 = Vector2(600, 610)

var state: VehicleState
var _damage_flash: float = 0.0
var _vehicle_sprite: Sprite2D


func _ready() -> void:
	z_index = 10
	_vehicle_sprite = Sprite2D.new()
	_vehicle_sprite.texture = VEHICLE_TEXTURE
	_vehicle_sprite.position = Vector2(800.0, 510.0)
	_vehicle_sprite.scale = Vector2(0.62, 0.62)
	_vehicle_sprite.z_index = -1
	add_child(_vehicle_sprite)


func setup(vehicle_state: VehicleState) -> void:
	state = vehicle_state
	queue_redraw()


func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta)
	_vehicle_sprite.modulate = Color("#ffb0a8") if _damage_flash > 0.0 else Color.WHITE
	queue_redraw()


func flash_damage() -> void:
	_damage_flash = 0.12


func floor_y(level: int) -> float:
	match level:
		1: return UPPER_FLOOR_Y
		2: return ROOF_FLOOR_Y
		_: return LOWER_FLOOR_Y


func _draw() -> void:
	if state == null:
		return
	_draw_section_bar(Vector2(LEFT_X - 32, 320), Vector2(12, 170), state.section_ratio(&"front"))
	_draw_section_bar(Vector2(RIGHT_X + 20, 320), Vector2(12, 170), state.section_ratio(&"rear"))
	_draw_section_bar(Vector2(650, TOP_Y - 22), Vector2(300, 10), state.section_ratio(&"roof"))
	_draw_section_bar(Vector2(650, BOTTOM_Y + 8), Vector2(300, 10), state.section_ratio(&"lower"))
	draw_arc(REPAIR_CONSOLE, 24.0, 0.0, TAU, 24, Color("#78f0d2"), 2.0)
	_draw_breach_state(&"front", Vector2(LEFT_X - 8, 500), Vector2.RIGHT)
	_draw_breach_state(&"rear", Vector2(RIGHT_X + 8, 500), Vector2.LEFT)
	_draw_breach_state(&"roof", Vector2(800, TOP_Y + 8), Vector2.DOWN)
	_draw_breach_state(&"lower", Vector2(800, BOTTOM_Y - 8), Vector2.UP)
	_draw_modules()


func _draw_breach_state(section: StringName, position_value: Vector2, inward: Vector2) -> void:
	if state.is_breached(section):
		draw_circle(position_value, 22.0, Color("#351a21"))
		draw_arc(position_value, 25.0, 0.0, TAU, 20, Color("#ff735f"), 4.0)
		draw_line(position_value, position_value + inward * 42.0, Color.WHITE, 5.0)
		draw_string(ThemeDB.fallback_font, position_value + Vector2(-38, -32), "BREACH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	elif state.breach_warning(section):
		var points := PackedVector2Array([position_value + Vector2(0, -18), position_value + Vector2(-18, 16), position_value + Vector2(18, 16)])
		draw_colored_polygon(points, Color("#e2a548"))
		draw_string(ThemeDB.fallback_font, position_value + Vector2(-34, 35), "侵入危険", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_modules() -> void:
	if state.module_system == null:
		return
	for module: VehicleModuleState in state.module_system.modules.values():
		var top_left: Vector2 = VehicleModuleSystem.GRID_ORIGIN + Vector2(module.grid_position) * VehicleModuleSystem.CELL_SIZE_PX
		var size: Vector2 = Vector2(module.definition.grid_size) * VehicleModuleSystem.CELL_SIZE_PX
		var color: Color = Color("#3c8d80") if module.powered else Color("#6a6060")
		if module.hp <= 0.0:
			color = Color("#8f3030")
		draw_rect(Rect2(top_left + Vector2(2, 2), size - Vector2(4, 4)), Color(color, 0.72), true)
		draw_rect(Rect2(top_left + Vector2(2, 2), size - Vector2(4, 4)), Color("#d5e2df"), false, 2.0)
		var label: String = {&"module_generator": "GEN", &"module_firing_port": "PORT", &"module_turret": "TURRET", &"module_workbench": "WORK"}.get(module.definition.id, "MOD")
		var status: String = "ON" if module.powered else "OFF"
		if module.overheated:
			status = "OVERHEAT"
		draw_string(ThemeDB.fallback_font, top_left + Vector2(6, 20), "%s %s" % [label, status], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if module.definition.id == &"module_turret":
			draw_string(ThemeDB.fallback_font, top_left + Vector2(6, 38), "HEAT %.0f" % module.heat, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_section_bar(pos: Vector2, size: Vector2, ratio: float) -> void:
	draw_rect(Rect2(pos, size), Color("#252129"), true)
	var color: Color = Color("#65c466") if ratio > 0.5 else Color("#e0a64c") if ratio > 0.0 else Color("#e34f4f")
	if size.x > size.y:
		draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), color, true)
	else:
		var filled: float = size.y * clampf(ratio, 0.0, 1.0)
		draw_rect(Rect2(pos + Vector2(0, size.y - filled), Vector2(size.x, filled)), color, true)
