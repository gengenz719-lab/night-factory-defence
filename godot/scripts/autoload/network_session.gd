extends Node

signal session_state_changed
signal session_ready
signal session_failed(message: String)
signal peer_roster_changed
signal character_roster_changed
signal run_requested(run_seed: int)

enum SessionRole { NONE, SOLO, HOST, CLIENT }

const HOST_PEER_ID: int = 1
const DEFAULT_PORT: int = 29118
const MAX_CLIENTS: int = 3
const CHANNEL_COUNT: int = 4

var role: SessionRole = SessionRole.NONE
var status_text: String = "未接続"
var offered_version: String = ""
var ready_peers: Dictionary = {}
var accepted_peers: Dictionary = {}
var selected_characters: Dictionary = {}
var expected_player_count: int = 1
var cached_local_peer_id: int = HOST_PEER_ID


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_solo() -> Error:
	disconnect_session()
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	role = SessionRole.SOLO
	cached_local_peer_id = HOST_PEER_ID
	expected_player_count = 1
	accepted_peers[HOST_PEER_ID] = true
	_set_status("ソロセッション準備完了")
	session_ready.emit()
	return OK


func create_host(port: int = DEFAULT_PORT, player_count: int = 2) -> Error:
	disconnect_session()
	if OS.has_feature("web"):
		return _fail("Web版ではオンラインホストを作成できません")
	var peer := ENetMultiplayerPeer.new()
	var result: Error = peer.create_server(port, MAX_CLIENTS, CHANNEL_COUNT)
	if result != OK:
		return _fail("ホストを開始できません: %s" % error_string(result))
	multiplayer.multiplayer_peer = peer
	role = SessionRole.HOST
	cached_local_peer_id = HOST_PEER_ID
	expected_player_count = clampi(player_count, 2, MAX_CLIENTS + 1)
	accepted_peers[HOST_PEER_ID] = true
	_set_status("ホスト待受中 port=%d" % port)
	session_ready.emit()
	return OK


func join_host(address: String, port: int = DEFAULT_PORT, version: String = AppState.GAME_VERSION) -> Error:
	disconnect_session()
	if OS.has_feature("web"):
		return _fail("Web版はソロプレイ専用です")
	var peer := ENetMultiplayerPeer.new()
	var result: Error = peer.create_client(address, port, CHANNEL_COUNT)
	if result != OK:
		return _fail("参加を開始できません: %s" % error_string(result))
	multiplayer.multiplayer_peer = peer
	role = SessionRole.CLIENT
	offered_version = version
	_set_status("接続中 %s:%d" % [address, port])
	return OK


func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	role = SessionRole.NONE
	ready_peers.clear()
	accepted_peers.clear()
	selected_characters.clear()
	expected_player_count = 1
	_set_status("未接続")


func is_host_authority() -> bool:
	return role in [SessionRole.SOLO, SessionRole.HOST]


func local_peer_id() -> int:
	return cached_local_peer_id


func connected_peer_ids() -> Array[int]:
	var result: Array[int] = [HOST_PEER_ID]
	for peer_id: int in accepted_peers:
		if peer_id != HOST_PEER_ID:
			result.append(peer_id)
	for peer_key: Variant in selected_characters:
		var peer_id: int = int(peer_key)
		if not result.has(peer_id):
			result.append(peer_id)
	result.sort()
	return result


func set_local_ready(value: bool) -> void:
	if value and not selected_characters.has(local_peer_id()):
		_fail("キャラクターを選択してください")
		return
	if role == SessionRole.CLIENT:
		ready_peers[local_peer_id()] = value
		_submit_ready.rpc_id(HOST_PEER_ID, value)
	elif is_host_authority():
		ready_peers[HOST_PEER_ID] = value
		peer_roster_changed.emit()
		_try_start_run()


func request_character_selection(character_id: StringName) -> void:
	if role == SessionRole.CLIENT:
		_submit_character_selection.rpc_id(HOST_PEER_ID, String(character_id))
	elif is_host_authority():
		_confirm_character_for_peer(HOST_PEER_ID, character_id)


func selected_character(peer_id: int) -> StringName:
	return StringName(str(selected_characters.get(peer_id, "")))


func request_run_start(run_seed: int) -> void:
	if not is_host_authority():
		return
	_begin_run.rpc(run_seed)
	_begin_run(run_seed)


func _try_start_run() -> void:
	if not is_host_authority() or accepted_peers.size() < expected_player_count:
		return
	for peer_id: int in accepted_peers:
		if not selected_characters.has(peer_id):
			return
		if not bool(ready_peers.get(peer_id, false)):
			return
	var seed_value: int = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	request_run_start(seed_value)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_version(version: String) -> void:
	if role != SessionRole.HOST:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if version != AppState.GAME_VERSION:
		_reject_version.rpc_id(sender_id, AppState.GAME_VERSION)
		_disconnect_rejected_peer(sender_id)
		return
	accepted_peers[sender_id] = true
	_accept_version.rpc_id(sender_id, AppState.GAME_VERSION)
	for peer_key: Variant in selected_characters:
		_confirm_character_selection.rpc_id(sender_id, int(peer_key), str(selected_characters[peer_key]))
	peer_roster_changed.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _accept_version(version: String) -> void:
	cached_local_peer_id = multiplayer.get_unique_id()
	accepted_peers[HOST_PEER_ID] = true
	accepted_peers[cached_local_peer_id] = true
	_set_status("接続済み version=%s" % version)
	session_ready.emit()
	peer_roster_changed.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _reject_version(required_version: String) -> void:
	_fail("バージョン不一致: ホスト=%s / 参加側=%s" % [required_version, offered_version])


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_ready(value: bool) -> void:
	if role != SessionRole.HOST:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not accepted_peers.has(sender_id):
		return
	if value and not selected_characters.has(sender_id):
		return
	ready_peers[sender_id] = value
	peer_roster_changed.emit()
	_try_start_run()


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_character_selection(character_id: String) -> void:
	if role != SessionRole.HOST:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if accepted_peers.has(sender_id):
		_confirm_character_for_peer(sender_id, StringName(character_id))


func _confirm_character_for_peer(peer_id: int, character_id: StringName) -> void:
	var definition := GameCatalog.get_definition(character_id) as CharacterDefinition
	if definition == null or not definition.tags.has(&"character"):
		return
	selected_characters[peer_id] = character_id
	ready_peers[peer_id] = false
	_confirm_character_selection.rpc(peer_id, String(character_id))
	character_roster_changed.emit()
	peer_roster_changed.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _confirm_character_selection(peer_id: int, character_id: String) -> void:
	selected_characters[peer_id] = StringName(character_id)
	ready_peers[peer_id] = false
	character_roster_changed.emit()
	peer_roster_changed.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _begin_run(run_seed: int) -> void:
	run_requested.emit(run_seed)


func _on_peer_connected(peer_id: int) -> void:
	if role == SessionRole.HOST:
		_set_status("参加者を認証中 peer=%d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	accepted_peers.erase(peer_id)
	ready_peers.erase(peer_id)
	selected_characters.erase(peer_id)
	peer_roster_changed.emit()
	if role == SessionRole.CLIENT:
		_fail("ホストから切断されました")


func _on_connected_to_server() -> void:
	_request_version.rpc_id(HOST_PEER_ID, offered_version)


func _on_connection_failed() -> void:
	_fail("ホストへ接続できませんでした")


func _on_server_disconnected() -> void:
	_fail("ホストとの接続が切れました")


func _disconnect_rejected_peer(peer_id: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _set_status(message: String) -> void:
	status_text = message
	session_state_changed.emit()


func _fail(message: String) -> Error:
	_set_status(message)
	session_failed.emit(message)
	return FAILED
