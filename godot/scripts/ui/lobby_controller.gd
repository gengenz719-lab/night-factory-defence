class_name LobbyController
extends Control

const RunScene: PackedScene = preload("res://scenes/game/run.tscn")

var status_label: Label
var address_input: LineEdit
var ready_button: Button
var mode_buttons: VBoxContainer
var character_panel: VBoxContainer
var roster_label: Label
var character_buttons: Dictionary = {}
var _run_started: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	NetworkSession.session_state_changed.connect(_refresh_status)
	NetworkSession.session_ready.connect(_show_ready)
	NetworkSession.session_failed.connect(_show_error)
	NetworkSession.peer_roster_changed.connect(_refresh_status)
	NetworkSession.character_roster_changed.connect(_refresh_character_selection)
	NetworkSession.run_requested.connect(_start_run)
	_handle_command_line()


func _build_ui() -> void:
	var ui_theme := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NfdJp.ttf"):
		ui_theme.default_font = load("res://assets/fonts/NfdJp.ttf") as Font
	ui_theme.default_font_size = 18
	theme = ui_theme
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("10141f")
	add_child(background)
	var panel := VBoxContainer.new()
	panel.position = Vector2(500, 150)
	panel.size = Vector2(600, 600)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override(&"separation", 18)
	add_child(panel)
	var title := Label.new()
	title.text = "ROAD OF THE DEAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 38)
	panel.add_child(title)
	mode_buttons = VBoxContainer.new()
	mode_buttons.add_theme_constant_override(&"separation", 12)
	panel.add_child(mode_buttons)
	_add_button("ソロ開始", _on_solo_pressed)
	_add_button("ホスト作成", _on_host_pressed)
	address_input = LineEdit.new()
	address_input.placeholder_text = "参加先IP (例: 127.0.0.1)"
	address_input.text = "127.0.0.1"
	address_input.custom_minimum_size = Vector2(520, 48)
	mode_buttons.add_child(address_input)
	_add_button("IP指定で参加", _on_join_pressed)
	character_panel = VBoxContainer.new()
	character_panel.visible = false
	character_panel.add_theme_constant_override(&"separation", 10)
	panel.add_child(character_panel)
	var prompt := Label.new()
	prompt.text = "CHARACTER SELECT（同じ役割も選択可）"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_panel.add_child(prompt)
	_add_character_button(&"character_gunner", "GUNNER  ライフル / Combat Focus")
	_add_character_button(&"character_engineer", "ENGINEER  リボルバー / Repair Drone")
	roster_label = Label.new()
	roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_panel.add_child(roster_label)
	ready_button = Button.new()
	ready_button.text = "準備完了"
	ready_button.custom_minimum_size = Vector2(520, 58)
	ready_button.visible = false
	ready_button.pressed.connect(_on_ready_pressed)
	panel.add_child(ready_button)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(520, 100)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)
	_refresh_status()


func _add_button(text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(520, 58)
	button.pressed.connect(callback)
	mode_buttons.add_child(button)


func _add_character_button(character_id: StringName, label_text: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(520, 48)
	button.pressed.connect(func() -> void: NetworkSession.request_character_selection(character_id))
	character_panel.add_child(button)
	character_buttons[character_id] = button


func _on_solo_pressed() -> void:
	NetworkSession.start_solo()


func _on_host_pressed() -> void:
	NetworkSession.create_host()


func _on_join_pressed() -> void:
	NetworkSession.join_host(address_input.text.strip_edges())


func _show_ready() -> void:
	mode_buttons.visible = false
	character_panel.visible = true
	ready_button.visible = true
	ready_button.disabled = true
	_refresh_character_selection()
	_refresh_status()
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke-test") or args.has("--network-test-host"):
		NetworkSession.request_character_selection(&"character_gunner")
	elif args.has("--network-test-client"):
		NetworkSession.request_character_selection(&"character_engineer")


func _on_ready_pressed() -> void:
	ready_button.disabled = true
	ready_button.text = "準備完了済み"
	NetworkSession.set_local_ready(true)


func _start_run(run_seed: int) -> void:
	if _run_started:
		return
	_run_started = true
	call_deferred(&"_instantiate_run", run_seed)


func _instantiate_run(run_seed: int) -> void:
	visible = false
	var run := RunScene.instantiate() as RunCoordinator
	get_parent().add_child(run)
	run.setup_network_run(run_seed)


func _refresh_status() -> void:
	if status_label == null:
		return
	status_label.text = "%s\n参加人数: %d / %d" % [
		NetworkSession.status_text,
		NetworkSession.connected_peer_ids().size(),
		NetworkSession.expected_player_count,
	]


func _refresh_character_selection() -> void:
	if ready_button == null:
		return
	var local_choice: StringName = NetworkSession.selected_character(NetworkSession.local_peer_id())
	var local_ready: bool = bool(NetworkSession.ready_peers.get(NetworkSession.local_peer_id(), false))
	ready_button.disabled = local_choice.is_empty() or local_ready
	ready_button.text = "準備完了済み" if local_ready else "準備完了"
	for key: Variant in character_buttons:
		(character_buttons[key] as Button).disabled = StringName(key) == local_choice
	var lines: PackedStringArray = []
	for peer_id: int in NetworkSession.connected_peer_ids():
		var choice := NetworkSession.selected_character(peer_id)
		var definition := GameCatalog.get_definition(choice) as CharacterDefinition
		lines.append("P%d: %s" % [peer_id, definition.role_name if definition != null else "選択待ち"])
	if roster_label != null:
		roster_label.text = "\n".join(lines)
	if not local_choice.is_empty() and not local_ready and (OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_user_args().has("--network-test-host") or OS.get_cmdline_user_args().has("--network-test-client")):
		call_deferred(&"_on_ready_pressed")


func _show_error(message: String) -> void:
	status_label.text = message
	if OS.get_cmdline_user_args().has("--network-test-client") and message.contains("バージョン不一致"):
		print("VERSION_TEST_PASS %s" % message)
		get_tree().quit(0)


func _handle_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--smoke-test"):
		NetworkSession.start_solo()
	elif args.has("--network-test-host"):
		NetworkSession.create_host(_argument_int(args, "--port=", NetworkSession.DEFAULT_PORT), 2)
	elif args.has("--network-test-client"):
		var version: String = _argument_string(args, "--version=", AppState.GAME_VERSION)
		NetworkSession.join_host(_argument_string(args, "--address=", "127.0.0.1"), _argument_int(args, "--port=", NetworkSession.DEFAULT_PORT), version)


func _argument_string(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for argument: String in args:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _argument_int(args: PackedStringArray, prefix: String, fallback: int) -> int:
	return _argument_string(args, prefix, str(fallback)).to_int()
