class_name LobbyController
extends Control

const RunScene: PackedScene = preload("res://scenes/game/run.tscn")

var status_label: Label
var address_input: LineEdit
var ready_button: Button
var mode_buttons: VBoxContainer
var _run_started: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	NetworkSession.session_state_changed.connect(_refresh_status)
	NetworkSession.session_ready.connect(_show_ready)
	NetworkSession.session_failed.connect(_show_error)
	NetworkSession.peer_roster_changed.connect(_refresh_status)
	NetworkSession.run_requested.connect(_start_run)
	_handle_command_line()


func _build_ui() -> void:
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


func _on_solo_pressed() -> void:
	NetworkSession.start_solo()


func _on_host_pressed() -> void:
	NetworkSession.create_host()


func _on_join_pressed() -> void:
	NetworkSession.join_host(address_input.text.strip_edges())


func _show_ready() -> void:
	mode_buttons.visible = false
	ready_button.visible = true
	_refresh_status()
	if OS.get_cmdline_user_args().has("--network-test-client"):
		call_deferred(&"_on_ready_pressed")


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


func _show_error(message: String) -> void:
	status_label.text = message
	if OS.get_cmdline_user_args().has("--network-test-client") and message.contains("バージョン不一致"):
		print("VERSION_TEST_PASS %s" % message)
		get_tree().quit(0)


func _handle_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--smoke-test"):
		NetworkSession.start_solo()
		NetworkSession.set_local_ready(true)
	elif args.has("--network-test-host"):
		NetworkSession.create_host(_argument_int(args, "--port=", NetworkSession.DEFAULT_PORT), 2)
		NetworkSession.set_local_ready(true)
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
