extends Node

## BGM・SE・音量バスの入口。音声機能は後続フェーズで実装する。

signal volume_changed(bus_name: StringName, linear_volume: float)


func notify_volume_changed(bus_name: StringName, linear_volume: float) -> void:
	volume_changed.emit(bus_name, linear_volume)
