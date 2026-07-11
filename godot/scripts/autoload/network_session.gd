extends Node

## WP1-4で接続処理を実装するためのAutoload骨組み。
## 現段階ではラン状態やゲームルールを所有しない。

signal session_state_changed


func notify_session_state_changed() -> void:
	session_state_changed.emit()
