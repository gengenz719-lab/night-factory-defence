class_name ScrollingBackground
extends Node2D

var scroll_speed: float = 92.0
var scroll_offset: float = 0.0


func _process(delta: float) -> void:
	# 車両は画面左向き。背景を左→右へ動かして左方向への走行を表現する。
	scroll_offset = fposmod(scroll_offset + scroll_speed * delta, 320.0)
	queue_redraw()


func _draw() -> void:
	# 空
	draw_rect(Rect2(0, 0, 1600, 900), Color("#171827"))
	draw_rect(Rect2(0, 120, 1600, 360), Color("#563044"))
	draw_rect(Rect2(0, 300, 1600, 290), Color("#b55a3c"))
	draw_circle(Vector2(1260, 220), 86.0, Color("#f6ad55"))
	draw_circle(Vector2(1260, 220), 70.0, Color("#ffd089"))

	# 遠景工場。レイヤーごとに異なる速度で右へ流す。
	_draw_city_layer(520.0, 0.22, Color("#3a3440"), 180.0)
	_draw_city_layer(610.0, 0.48, Color("#282c36"), 120.0)

	# ガードレールと道路
	draw_rect(Rect2(0, 665, 1600, 12), Color("#494c52"))
	draw_rect(Rect2(0, 677, 1600, 223), Color("#171a20"))
	draw_line(Vector2(0, 750), Vector2(1600, 750), Color("#4b4a43"), 4.0)
	for i: int in range(-2, 10):
		var dash_x: float = fposmod(float(i) * 240.0 + scroll_offset * 1.8, 1920.0) - 160.0
		draw_rect(Rect2(dash_x, 808, 110, 8), Color("#d29b4c"))

	# 手前の瓦礫
	for i: int in range(-2, 14):
		var rubble_x: float = fposmod(float(i) * 145.0 + scroll_offset * 2.35, 1885.0) - 140.0
		var rubble_y: float = 850.0 + float((i * 17) % 26)
		draw_circle(Vector2(rubble_x, rubble_y), 8.0 + float(i % 3) * 4.0, Color("#2a292b"))


func _draw_city_layer(base_y: float, speed_factor: float, color: Color, spacing: float) -> void:
	var layer_offset: float = scroll_offset * speed_factor
	for i: int in range(-3, 14):
		var x: float = fposmod(float(i) * spacing + layer_offset, 2000.0) - 200.0
		var height: float = 70.0 + float((i * 43) % 120)
		draw_rect(Rect2(x, base_y - height, spacing * 0.62, height), color)
		if i % 4 == 0:
			draw_rect(Rect2(x + 22.0, base_y - height - 72.0, 22.0, 72.0), color)
			draw_circle(Vector2(x + 33.0, base_y - height - 72.0), 18.0, color)
