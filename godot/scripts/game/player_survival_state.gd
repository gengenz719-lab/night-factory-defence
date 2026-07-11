class_name PlayerSurvivalState
extends RefCounted

signal downed
signal departed
signal revived
signal returned
signal changed

var definition: CharacterDefinition
var max_hp: float = 0.0
var hp: float = 0.0
var invulnerable_time: float = 0.0
var dodge_cooldown: float = 0.0
var downed_time: float = 0.0
var return_time: float = 0.0
var revive_progress: float = 0.0
var is_downed: bool = false
var is_departed: bool = false
var revive_idle_time: float = 0.0


func setup(character_definition: CharacterDefinition) -> void:
	definition = character_definition
	max_hp = definition.max_hp
	hp = max_hp


func authority_tick(delta: float) -> void:
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	if is_downed:
		downed_time = maxf(0.0, downed_time - delta)
		revive_idle_time += delta
		if revive_idle_time > definition.revive_interrupt_grace_seconds:
			revive_progress = 0.0
		if downed_time <= 0.0:
			is_downed = false
			is_departed = true
			return_time = definition.return_wait_seconds
			revive_progress = 0.0
			departed.emit()
			changed.emit()
	elif is_departed:
		return_time = maxf(0.0, return_time - delta)
		if return_time <= 0.0:
			is_departed = false
			hp = max_hp * definition.return_health_ratio
			returned.emit()
			changed.emit()


func take_damage(amount: float) -> bool:
	if invulnerable_time > 0.0 or is_downed or is_departed:
		return false
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		is_downed = true
		downed_time = definition.downed_grace_seconds
		revive_progress = 0.0
		revive_idle_time = 0.0
		downed.emit()
	changed.emit()
	return true


func try_dodge() -> bool:
	if dodge_cooldown > 0.0 or is_downed or is_departed:
		return false
	dodge_cooldown = definition.dodge_cooldown_seconds
	invulnerable_time = maxf(invulnerable_time, definition.dodge_invulnerability_seconds)
	changed.emit()
	return true


func add_revive_progress(delta: float) -> bool:
	if not is_downed:
		return false
	revive_idle_time = 0.0
	revive_progress += delta
	if revive_progress < definition.revive_seconds:
		changed.emit()
		return false
	is_downed = false
	hp = max_hp * definition.revive_health_ratio
	invulnerable_time = definition.revive_invulnerability_seconds
	downed_time = 0.0
	revive_progress = 0.0
	revived.emit()
	changed.emit()
	return true


func apply_snapshot(
	health: float,
	downed_value: bool,
	departed_value: bool,
	invulnerability: float,
	dodge_cooldown_value: float,
	down_time: float,
	return_time_value: float,
	revive_progress_value: float
) -> void:
	hp = clampf(health, 0.0, max_hp)
	is_downed = downed_value
	is_departed = departed_value
	invulnerable_time = maxf(0.0, invulnerability)
	dodge_cooldown = maxf(0.0, dodge_cooldown_value)
	downed_time = maxf(0.0, down_time)
	return_time = maxf(0.0, return_time_value)
	revive_progress = maxf(0.0, revive_progress_value)
