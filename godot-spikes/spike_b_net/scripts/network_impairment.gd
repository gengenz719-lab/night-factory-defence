class_name NetworkImpairment
extends RefCounted

const DEFAULT_ONE_WAY_DELAY_MS: int = 75
const DEFAULT_PACKET_LOSS_RATE: float = 0.02

var enabled: bool = true
var one_way_delay_ms: int = DEFAULT_ONE_WAY_DELAY_MS
var packet_loss_rate: float = DEFAULT_PACKET_LOSS_RATE
var unreliable_sent: int = 0
var unreliable_dropped: int = 0
var reliable_sent: int = 0
var reliable_retries: int = 0
var estimated_bytes_sent: int = 0

var _queue: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_random.seed = seed_value


func enqueue_unreliable(action: Callable, estimated_bytes: int) -> void:
	unreliable_sent += 1
	estimated_bytes_sent += estimated_bytes
	if enabled and _random.randf() < packet_loss_rate:
		unreliable_dropped += 1
		return
	_enqueue(action, one_way_delay_ms if enabled else 0)


func enqueue_reliable(action: Callable, estimated_bytes: int) -> void:
	reliable_sent += 1
	estimated_bytes_sent += estimated_bytes
	var delay_ms: int = one_way_delay_ms if enabled else 0
	if enabled and _random.randf() < packet_loss_rate:
		# ENet reliableの再送をアプリ層で近似し、破棄せず1 RTT分だけ遅らせる。
		reliable_retries += 1
		delay_ms += one_way_delay_ms * 2
	_enqueue(action, delay_ms)


func process_pending() -> void:
	var now_ms: int = Time.get_ticks_msec()
	var remaining: Array[Dictionary] = []
	for item: Dictionary in _queue:
		if int(item["due_ms"]) <= now_ms:
			var action: Callable = item["action"] as Callable
			action.call()
		else:
			remaining.append(item)
	_queue = remaining


func pending_count() -> int:
	return _queue.size()


func _enqueue(action: Callable, delay_ms: int) -> void:
	_queue.append({
		"due_ms": Time.get_ticks_msec() + delay_ms,
		"action": action,
	})
