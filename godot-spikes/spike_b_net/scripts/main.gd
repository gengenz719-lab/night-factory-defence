extends Node2D

const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_PORT: int = 29117
const MAX_CLIENTS: int = 1
const CHANNEL_COUNT: int = 4

var role: String = "host"
var address: String = DEFAULT_ADDRESS
var port: int = DEFAULT_PORT
var duration_seconds: float = 30.0
var elapsed_seconds: float = 0.0
var connected: bool = false
var had_remote_peer: bool = false
var status_text: String = "起動中"


func _ready() -> void:
	_parse_arguments()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	if role == "host":
		_start_host()
	else:
		_start_client()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed_seconds += delta
	queue_redraw()
	if duration_seconds > 0.0 and elapsed_seconds >= duration_seconds:
		print("SPIKE_B_SHORT_RUN_COMPLETE role=%s connected=%s" % [role, connected])
		var succeeded: bool = connected or (role == "host" and had_remote_peer)
		get_tree().quit(0 if succeeded else 2)


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color("101722"))
	draw_string(ThemeDB.fallback_font, Vector2(32.0, 50.0), "Spike B: ENet 2-player", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color("e8f1ff"))
	draw_string(ThemeDB.fallback_font, Vector2(32.0, 90.0), "role=%s  %s" % [role, status_text], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("8fd3ff"))


func _parse_arguments() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument == "--host":
			role = "host"
		elif argument == "--client":
			role = "client"
		elif argument.begins_with("--address="):
			address = argument.trim_prefix("--address=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
		elif argument.begins_with("--duration="):
			duration_seconds = argument.trim_prefix("--duration=").to_float()


func _start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENTS, CHANNEL_COUNT)
	if error != OK:
		push_error("ENetサーバーを開始できません: %s" % error_string(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	connected = true
	status_text = "待受中 port=%d" % port
	print("SPIKE_B_HOST_READY port=%d" % port)


func _start_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port, CHANNEL_COUNT)
	if error != OK:
		push_error("ENetクライアントを開始できません: %s" % error_string(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	status_text = "接続中 %s:%d" % [address, port]
	print("SPIKE_B_CLIENT_CONNECTING address=%s port=%d" % [address, port])


func _on_peer_connected(peer_id: int) -> void:
	connected = true
	had_remote_peer = true
	status_text = "接続済み peer=%d" % peer_id
	print("SPIKE_B_PEER_CONNECTED role=%s peer=%d" % [role, peer_id])


func _on_peer_disconnected(peer_id: int) -> void:
	connected = false
	status_text = "切断 peer=%d" % peer_id
	print("SPIKE_B_PEER_DISCONNECTED role=%s peer=%d" % [role, peer_id])


func _on_connected_to_server() -> void:
	connected = true
	status_text = "ホストへ接続済み"
	print("SPIKE_B_CLIENT_CONNECTED own_id=%d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	connected = false
	status_text = "接続失敗"
	push_error("ホストへの接続に失敗しました")
	get_tree().quit(2)
