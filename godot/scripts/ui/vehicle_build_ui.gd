class_name VehicleBuildUI
extends CanvasLayer

signal placement_requested(module_id: StringName, position: Vector2i)
signal priority_requested(instance_id: int, priority: int)

var module_system: VehicleModuleSystem
var root: Control
var overlay: ColorRect
var toggle_button: Button
var grid: GridContainer
var grid_buttons: Array[Button] = []
var detail_label: Label
var status_label: Label
var selected_module_id: StringName = &"module_turret"
var selected_instance_id: int = 0
var prepare_mode: bool = true


func setup(system: VehicleModuleSystem) -> void:
	module_system = system
	module_system.layout_changed.connect(refresh)
	module_system.values_changed.connect(refresh)
	module_system.placement_rejected.connect(show_message)
	refresh()


func _ready() -> void:
	layer = 110
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui_theme := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NfdJp.ttf"):
		ui_theme.default_font = load("res://assets/fonts/NfdJp.ttf") as Font
	ui_theme.default_font_size = 17
	root.theme = ui_theme
	add_child(root)
	toggle_button = Button.new()
	toggle_button.position = Vector2(1015, 18)
	toggle_button.size = Vector2(180, 52)
	toggle_button.text = "車両改装 [B]"
	toggle_button.pressed.connect(toggle)
	root.add_child(toggle_button)
	_build_overlay()


func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.position = Vector2(110, 90)
	overlay.size = Vector2(1380, 720)
	overlay.color = Color(0.025, 0.04, 0.06, 0.97)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var title := Label.new()
	title.position = Vector2(28, 16)
	title.size = Vector2(1100, 52)
	title.text = "車両改装 － モジュールを選び、8×4グリッドへ配置"
	title.add_theme_font_size_override(&"font_size", 26)
	overlay.add_child(title)
	var close_button := Button.new()
	close_button.position = Vector2(1210, 16)
	close_button.size = Vector2(140, 48)
	close_button.text = "閉じる [B]"
	close_button.pressed.connect(toggle)
	overlay.add_child(close_button)
	_build_module_list()
	grid = GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(315, 115)
	grid.size = Vector2(720, 440)
	grid.add_theme_constant_override(&"h_separation", 5)
	grid.add_theme_constant_override(&"v_separation", 5)
	overlay.add_child(grid)
	for y_value: int in 4:
		for x_value: int in 8:
			var button := Button.new()
			button.custom_minimum_size = Vector2(84, 98)
			button.pressed.connect(_on_grid_pressed.bind(Vector2i(x_value, y_value)))
			grid.add_child(button)
			grid_buttons.append(button)
	detail_label = Label.new()
	detail_label.position = Vector2(1060, 110)
	detail_label.size = Vector2(285, 330)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.add_child(detail_label)
	for priority_value: int in [3, 2, 1]:
		var priority_button := Button.new()
		priority_button.position = Vector2(1060, 450 + (3 - priority_value) * 52)
		priority_button.size = Vector2(285, 44)
		priority_button.text = "電力優先度 %d" % priority_value
		priority_button.pressed.connect(_on_priority_pressed.bind(priority_value))
		overlay.add_child(priority_button)
	status_label = Label.new()
	status_label.position = Vector2(315, 585)
	status_label.size = Vector2(1030, 95)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.add_child(status_label)


func _build_module_list() -> void:
	var list := VBoxContainer.new()
	list.position = Vector2(25, 110)
	list.size = Vector2(265, 470)
	list.add_theme_constant_override(&"separation", 10)
	overlay.add_child(list)
	for module_id: StringName in [&"module_generator", &"module_firing_port", &"module_turret", &"module_workbench"]:
		var definition := GameCatalog.get_definition(module_id) as ModuleDefinition
		var button := Button.new()
		button.custom_minimum_size = Vector2(265, 82)
		button.text = "%s\n%d Scrap / 電力 %+d" % [definition.fallback_display_name, definition.scrap_cost, definition.power_generation - definition.power_consumption]
		button.pressed.connect(_select_module.bind(module_id))
		list.add_child(button)


func toggle() -> void:
	if not prepare_mode:
		show_message("改装できるのは準備中だけです")
		return
	overlay.visible = not overlay.visible
	refresh()


func set_prepare_mode(value: bool) -> void:
	prepare_mode = value
	toggle_button.visible = value
	if not value:
		overlay.visible = false


func refresh() -> void:
	if module_system == null or grid_buttons.is_empty():
		return
	var selected_definition := GameCatalog.get_definition(selected_module_id) as ModuleDefinition
	for y_value: int in module_system.vehicle_definition.grid_height:
		for x_value: int in module_system.vehicle_definition.grid_width:
			var cell := Vector2i(x_value, y_value)
			var button: Button = grid_buttons[y_value * module_system.vehicle_definition.grid_width + x_value]
			var placed: VehicleModuleState = module_system.module_at_cell(cell)
			if placed != null:
				button.text = "%s\n%s P%d\nHP %.0f%%" % [_short_name(placed.definition.id), "ON" if placed.powered else "OFF", placed.priority, placed.hp_ratio() * 100.0]
				button.modulate = Color.WHITE
			else:
				var reason: String = module_system.validate_placement(selected_definition, cell)
				button.text = "%d,%d\n%s" % [x_value, y_value, "配置可" if reason.is_empty() else "配置不可"]
				button.modulate = Color("#6aaee8") if reason.is_empty() else Color("#e0b64c") if reason.contains("通路") or reason.contains("はしご") else Color("#d86b6b")
	var selected_module: VehicleModuleState = module_system.modules.get(selected_instance_id) as VehicleModuleState
	if selected_module != null:
		detail_label.text = "%s\n\nHP %.0f / %.0f\n電力 %s\n優先度 %d\n熱 %.0f / %.0f\n\n配置済み設備を選択中" % [selected_module.definition.fallback_display_name, selected_module.hp, selected_module.definition.max_hp, "稼働" if selected_module.powered else "停止", selected_module.priority, selected_module.heat, selected_module.definition.heat_limit]
	else:
		detail_label.text = "%s\n\n%s\nサイズ %d×%d\n価格 %d Scrap\n電力 %+d\nHP %.0f" % [selected_definition.fallback_display_name, selected_definition.fallback_description, selected_definition.grid_size.x, selected_definition.grid_size.y, selected_definition.scrap_cost, selected_definition.power_generation - selected_definition.power_consumption, selected_definition.max_hp]
	status_label.text = "Scrap %d　電力 %d供給 / %d要求 / %d使用　%s" % [module_system.scrap, module_system.power_generated, module_system.power_requested, module_system.power_consumed, "電力不足: 低優先設備を停止" if module_system.power_consumed < module_system.power_requested else "全設備稼働可能"]


func show_message(message: String) -> void:
	if status_label != null:
		status_label.text = message


func _select_module(module_id: StringName) -> void:
	selected_module_id = module_id
	selected_instance_id = 0
	refresh()


func _on_grid_pressed(position: Vector2i) -> void:
	var placed: VehicleModuleState = module_system.module_at_cell(position)
	if placed != null:
		selected_instance_id = placed.instance_id
		selected_module_id = placed.definition.id
		refresh()
		return
	placement_requested.emit(selected_module_id, position)


func _on_priority_pressed(priority_value: int) -> void:
	if selected_instance_id > 0:
		priority_requested.emit(selected_instance_id, priority_value)


func _short_name(module_id: StringName) -> String:
	return {&"module_generator": "GEN", &"module_firing_port": "PORT", &"module_turret": "TURRET", &"module_workbench": "WORK"}.get(module_id, "MOD")
