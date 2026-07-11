class_name GameHUD
extends CanvasLayer

signal relic_selected(index: int)
signal route_selected(index: int)

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
var selection_mode: StringName = &"none"


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

	player_label = _make_label(Vector2(20, 18), Vector2(420, 170), 17, Color("#e9f5ff"))
	wave_label = _make_label(Vector2(615, 16), Vector2(370, 86), 28, Color.WHITE)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vehicle_label = _make_label(Vector2(1210, 18), Vector2(370, 125), 18, Color("#f7ead8"))
	vehicle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_label = _make_label(Vector2(18, 805), Vector2(650, 80), 16, Color("#c5c5ca"))
	message_label = _make_label(Vector2(520, 730), Vector2(560, 80), 20, Color("#7ef1d4"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_make_panel(Rect2(10, 10, 435, 182), Color(0.04, 0.06, 0.09, 0.86), -1)
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


func update_status(wave: int, max_wave: int, state_text: String, time_left: float, _player: CrewPlayer, vehicle: VehicleState, kills: int, relics: Array[RelicDefinition]) -> void:
	wave_label.text = "WAVE %d / %d\n%s   %02d:%02d" % [wave, max_wave, state_text, floori(time_left) / 60, floori(time_left) % 60]
	var breach_text: String = "なし" if vehicle.open_breach_sections().is_empty() else ",".join(vehicle.open_breach_sections())
	vehicle_label.text = "車体  %d / %d\n前 %.0f%%  屋根 %.0f%%  後 %.0f%%\n補給 %d 電力 %d/%d Scrap %d\n侵入口: %s" % [
		roundi(vehicle.hull), roundi(vehicle.max_hull),
		vehicle.section_ratio(&"front") * 100.0,
		vehicle.section_ratio(&"roof") * 100.0,
		vehicle.section_ratio(&"rear") * 100.0,
		roundi(vehicle.supplies), vehicle.module_system.power_consumed, vehicle.module_system.power_generated, vehicle.module_system.scrap,
		breach_text,
	]
	help_label.text = "A/D 移動  SPACE ジャンプ  SHIFT 回避  Q 固有能力\n左クリック 射撃  E 修理/蘇生  B 車両改装(準備中)  F1/F2 テスト短縮"
	message_label.text = "取得: %s" % " / ".join(_relic_names(relics)) if not relics.is_empty() else "車両を守りながらWaveを耐えろ"


func update_team_status(players_by_peer: Dictionary, local_peer_id: int, kills: int) -> void:
	var lines := PackedStringArray()
	var peer_ids: Array[int] = []
	for peer_key: Variant in players_by_peer:
		peer_ids.append(int(peer_key))
	peer_ids.sort()
	for index: int in peer_ids.size():
		var peer_id: int = peer_ids[index]
		var crew := players_by_peer[peer_id] as CrewPlayer
		var marker: String = "▶" if peer_id == local_peer_id else " "
		var state_text: String = "HP %d/%d" % [roundi(crew.survival.hp), roundi(crew.survival.max_hp)]
		if crew.survival.is_downed:
			state_text = "DOWN %.0fs  蘇生 %.0f%%" % [
				crew.survival.downed_time,
				100.0 * crew.survival.revive_progress / crew.definition.revive_seconds,
			]
		elif crew.survival.is_departed:
			state_text = "離脱中  復帰 %.0fs" % crew.survival.return_time
		var ability_text: String = "%s %.1fs" % [crew.definition.ability_name, crew.ability_active_time] if crew.ability_active_time > 0.0 else "%s CD %.1fs" % [crew.definition.ability_name, crew.ability_cooldown]
		lines.append("%sP%d %s  %s  回避CD %.1fs  %s" % [marker, index + 1, crew.definition.role_name, state_text, crew.survival.dodge_cooldown, ability_text])
	lines.append("チーム撃破 %d" % kills)
	player_label.text = "\n".join(lines)


func show_relic_choices(choices: Array[RelicDefinition]) -> void:
	overlay.visible = true
	selection_mode = &"relic"
	overlay_title.text = "WAVE CLEAR － 共有レリック投票"
	end_label.text = "投票: クリック、または数字キー 1 / 2 / 3"
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


func show_route_choices(choices: Array[RouteNodeDefinition]) -> void:
	overlay.visible = true
	selection_mode = &"route"
	overlay_title.text = "NEXT WAVE － 2択ルート投票"
	end_label.text = "投票: クリック、または数字キー 1 / 2"
	for child: Node in overlay_cards.get_children():
		child.queue_free()
	for index: int in choices.size():
		var route: RouteNodeDefinition = choices[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(500, 300)
		button.text = "%d\n%s\n\n脅威: %s / 主力: %s\n危険: %s\n報酬: %s\n\n%s" % [
			index + 1, route.fallback_display_name, route.threat_label,
			route.primary_enemy_id, route.danger_text, route.reward_text,
			route.fallback_description,
		]
		button.add_theme_font_size_override(&"font_size", 21)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#36566d" if route.node_type == &"road" else "#76533e", 0.82)
		normal.border_color = Color("#e2d3ad")
		normal.set_border_width_all(3)
		normal.corner_radius_top_left = 12
		normal.corner_radius_top_right = 12
		normal.corner_radius_bottom_left = 12
		normal.corner_radius_bottom_right = 12
		button.add_theme_stylebox_override(&"normal", normal)
		button.pressed.connect(_on_route_button.bind(index))
		overlay_cards.add_child(button)


func update_vote_status(count_text: String, time_left: float) -> void:
	if overlay.visible and selection_mode in [&"relic", &"route"]:
		end_label.text = "%s    残り %02d秒\n選び直し可。結果はホストが確定" % [count_text, ceili(time_left)]


func show_end(victory: bool, kills: int, relics: Array[RelicDefinition]) -> void:
	overlay.visible = true
	selection_mode = &"end"
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
	selection_mode = &"none"


func _unhandled_input(event: InputEvent) -> void:
	if not overlay.visible or selection_mode not in [&"relic", &"route"]:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_on_choice_button(0)
			KEY_2:
				_on_choice_button(1)
			KEY_3:
				_on_choice_button(2)


func _on_relic_button(index: int) -> void:
	relic_selected.emit(index)


func _on_route_button(index: int) -> void:
	route_selected.emit(index)


func _on_choice_button(index: int) -> void:
	if index < 0 or index >= overlay_cards.get_child_count():
		return
	if selection_mode == &"relic":
		_on_relic_button(index)
	elif selection_mode == &"route":
		_on_route_button(index)


func _relic_names(relics: Array[RelicDefinition]) -> PackedStringArray:
	var names := PackedStringArray()
	for relic: RelicDefinition in relics:
		names.append(relic.fallback_display_name)
	return names


func _category_name(category: StringName) -> String:
	return {&"combat": "戦闘", &"vehicle": "車両", &"special": "特殊"}.get(category, "特殊")


func _category_color(category: StringName) -> Color:
	return {&"combat": Color("#b94e45"), &"vehicle": Color("#3b8290"), &"special": Color("#76538d")}.get(category, Color("#76538d"))
