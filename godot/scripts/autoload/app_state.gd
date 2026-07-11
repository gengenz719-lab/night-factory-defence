extends Node

## ゲーム全体で共有する起動状態だけを保持する。
## Waveや車両HPなどのラン固有状態はここへ置かない。

signal screen_change_requested(screen_id: StringName)

const GAME_VERSION: String = "0.1.0"


func request_screen_change(screen_id: StringName) -> void:
	screen_change_requested.emit(screen_id)
