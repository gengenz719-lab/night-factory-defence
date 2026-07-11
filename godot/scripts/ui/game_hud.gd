class_name GameHUD
extends CanvasLayer

signal relic_selected(index: int)

var root_control: Control
var player_label: Label
var wave_label: Label
var vehicle_label: Label
var help_label: Label
var message_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_cards: HBoxContainer
var end_label: Label


func _ready() -> void:
	layer = 100
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var ui_theme := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NfdJp.ttf"):
		ui_theme.default_font = load("res://assets/fonts/NfdJp.ttf") as Font
	ui_theme.default_font_size = 18
	root_control.theme = ui_theme

	player_label = _make_label(Vector2(20, 18), Vector2(350, 100), 19, Color("#e9f5ff"))
	wave_label = _make_label(Vector2(615, 16), Vector2(370, 86), 28, Color.WHITE)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vehicle_label = _make_label(Vector2(1210, 18), Vector2(370, 125), 18, Color("#f7ead8"))
	vehicle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_label = _make_label(Vector2(18, 805), Vector2(650, 80), 16, Color("#c5c5ca"))
	message_label = _make_label(Vector2(520, 730), Vector2(560, 80), 20, Color("#7ef1d4"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_make_panel(Rect2(10, 10, 365, 112), Color(0.04, 0.06, 0.09, 0.86), -1)
	_make_panel(Rect2(600, 10, 400, 92), Color(0.04, 0.06, 0.09, 0.90), -1)
	_make_panel(Rect2(1200, 10, 390, 145), Color(0.04, 0.06, 0.09, 0.86), -1)

	# パネルを先に描くため、ラベルを前面へ戻す。
	for label: Label in [player_label, wave_label, vehicle_label, help_label, message_label]:
		root_control.move_child(label, root_control.get_child_count() - 1)

	_build_overlay()


func _make_label(pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root_control.add_child(label)
	return label


func _make_panel(rect: Rect2, color: Color, z: int = 0) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.z_index = z
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#59606d")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override(&"panel", style)
	root_control.add_child(panel)
	return panel


func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.025, 0.04, 0.92)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root_control.add_child(overlay)

	var box := VBoxContainer.new()
	box.position = Vector2(190, 135)
	box.size = Vector2(1220, 610)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 28)
	overlay.add_child(box)

	overlay_title = Label.new()
	overlay_title.custom_minimum_size = Vector2(1200, 80)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override(&"font_size", 34)
	box.add_child(overlay_title)

	overlay_cards = HBoxContainer.new()
	overlay_cards.custom_minimum_size = Vector2(1200, 330)
	overlay_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_cards.add_theme_constant_override(&"separation", 28)
	box.add_child(overlay_cards)

	end_label = Label.new()
	end_label.custom_minimum_size = Vector2(1200, 110)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override(&"font_size", 22)
	box.add_child(end_label)


func update_status(wave: int, max_wave: int, state_text: String, time_left: float, player: CrewPlayer, vehicle: SurvivalVehicle, kills: int, relics: Array[RelicDefinition]) -> void:
	var hp_text: String = "DOWN" if player.is_downed else "%d / %d" % [roundi(player.hp), roundi(player.max_hp)]
	player_label.text = "P1  ガンナー\nHP  %s\n撃破  %d" % [hp_text, kills]
	wave_label.text = "WAVE %d / %d\n%s   %02d:%02d" % [wave, max_wave, state_text, floori(time_left) / 60, floori(time_left) % 60]
	vehicle_label.text = "車体  %d / %d\n前 %.0f%%  屋根 %.0f%%  後 %.0f%%\n補給 %d   レリック %d" % [
		roundi(vehicle.hull), roundi(vehicle.max_hull),
		vehicle.section_ratio(&"front") * 100.0,
		vehicle.section_ratio(&"roof") * 100.0,
		vehicle.section_ratio(&"rear") * 100.0,
		roundi(vehicle.supplies), relics.size(),
	]
	help_label.text = "A/D 移動  SPACE ジャンプ/はしご↑  S はしご↓\n左クリック 射撃  E 工作台で修理  F1 即開始  F2 Wave短縮"
	message_label.text = "取得: %s" % " / ".join(_relic_names(relics)) if not relics.is_empty() else "車両を守りながらWaveを耐えろ"


func show_relic_choices(choices: Array[RelicDefinition]) -> void:
	overlay.visible = true
	overlay_title.text = "WAVE CLEAR － 共有レリックを選択"
	end_label.text = "クリック、または数字キー 1 / 2 / 3"
	for child: Node in overlay_cards.get_children():
		child.queue_free()
	for index: int in range(choices.size()):
		var relic: RelicDefinition = choices[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(350, 300)
		button.text = "%d\n[%s]\n\n%s\n\n%s" % [index + 1, _category_name(relic.category), relic.fallback_display_name, relic.fallback_description]
		button.add_theme_font_size_override(&"font_size", 22)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(_category_color(relic.category), 0.78)
		normal.border_color = Color("#d8c8ae")
		normal.set_border_width_all(3)
		normal.corner_radius_top_left = 12
		normal.corner_radius_top_right = 12
		normal.corner_radius_bottom_left = 12
		normal.corner_radius_bottom_right = 12
		button.add_theme_stylebox_override(&"normal", normal)
		button.pressed.connect(_on_relic_button.bind(index))
		overlay_cards.add_child(button)


func show_end(victory: bool, kills: int, relics: Array[RelicDefinition]) -> void:
	overlay.visible = true
	overlay_title.text = "PROTOTYPE CLEAR" if victory else "VEHICLE DESTROYED"
	for child: Node in overlay_cards.get_children():
		child.queue_free()
	var summary := Label.new()
	summary.custom_minimum_size = Vector2(900, 260)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override(&"font_size", 28)
	summary.text = "2 Wave テスト完了\n撃破数: %d\nレリック: %s" % [kills, " / ".join(_relic_names(relics)) if not relics.is_empty() else "なし"] if victory else "車両が破壊された\n撃破数: %d" % kills
	overlay_cards.add_child(summary)
	end_label.text = "Rキーで最初から再テスト"


func hide_overlay() -> void:
	overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not overlay.visible or overlay_title.text.contains("CLEAR") == false or overlay_title.text.contains("PROTOTYPE"):
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_on_relic_button(0)
			KEY_2:
				_on_relic_button(1)
			KEY_3:
				_on_relic_button(2)


func _on_relic_button(index: int) -> void:
	overlay.visible = false
	relic_selected.emit(index)


func _relic_names(relics: Array[RelicDefinition]) -> PackedStringArray:
	var names := PackedStringArray()
	for relic: RelicDefinition in relics:
		names.append(relic.fallback_display_name)
	return names


func _category_name(category: StringName) -> String:
	return {&"combat": "戦闘", &"vehicle": "車両", &"special": "特殊"}.get(category, "特殊")


func _category_color(category: StringName) -> Color:
	return {&"combat": Color("#b94e45"), &"vehicle": Color("#3b8290"), &"special": Color("#76538d")}.get(category, Color("#76538d"))
