class_name StageDirector
extends Node

signal prepare_started(wave: WaveDefinition)
signal combat_started(wave: WaveDefinition)
signal reward_requested
signal victory_requested

enum RunState { PREPARE, COMBAT, REWARD, VICTORY, DEFEAT }

var state: RunState = RunState.PREPARE
var state_time: float = 0.0
var wave_index: int = 0
var wave_definitions: Array[WaveDefinition] = []


func setup(definitions: Array[WaveDefinition]) -> void:
	wave_definitions = definitions
	wave_index = 0
	begin_prepare()


func _process(delta: float) -> void:
	if state not in [RunState.PREPARE, RunState.COMBAT]:
		return
	state_time -= delta
	if state_time > 0.0:
		return
	if state == RunState.PREPARE:
		begin_combat()
	else:
		finish_wave()


func begin_prepare() -> void:
	state = RunState.PREPARE
	state_time = current_wave().prepare_duration_seconds
	prepare_started.emit(current_wave())


func begin_combat() -> void:
	state = RunState.COMBAT
	state_time = current_wave().duration_seconds
	combat_started.emit(current_wave())


func finish_wave() -> void:
	if state != RunState.COMBAT:
		return
	if wave_index >= wave_definitions.size() - 1:
		state = RunState.VICTORY
		victory_requested.emit()
	else:
		state = RunState.REWARD
		reward_requested.emit()


func complete_reward() -> void:
	wave_index += 1
	begin_prepare()


func mark_defeat() -> void:
	state = RunState.DEFEAT


func current_wave() -> WaveDefinition:
	return wave_definitions[wave_index]


func wave_number() -> int:
	return current_wave().wave_number


func state_text() -> String:
	return ["準備", "走行戦闘", "報酬", "勝利", "敗北"][state]
