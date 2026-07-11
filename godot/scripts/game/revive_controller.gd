class_name ReviveController
extends Node

const INTENT_GRACE_SECONDS: float = 0.12
const MAX_REVIVE_CONTRIBUTORS: int = 2

var players_by_peer: Dictionary = {}
var vehicle: VehicleState
var revive_target_by_peer: Dictionary = {}
var interact_intent_until: Dictionary = {}
var revives_confirmed: int = 0


func setup(players: Dictionary, vehicle_state: VehicleState) -> void:
	players_by_peer = players
	vehicle = vehicle_state


func handle_interact_intent(
	peer_id: int,
	player: CrewPlayer,
	wants_interact: bool,
	authority_time: float,
	intent_delta: float
) -> void:
	if not wants_interact or player.survival.is_downed or player.survival.is_departed:
		_clear_peer_intent(peer_id)
		return
	var revive_target: CrewPlayer = _find_revive_target(player)
	if revive_target != null:
		revive_target_by_peer[peer_id] = revive_target.peer_id
		interact_intent_until[peer_id] = authority_time + INTENT_GRACE_SECONDS
	else:
		_clear_peer_intent(peer_id)
		vehicle.repair_at(player.position, intent_delta, player.repair_multiplier)


func authority_tick(delta: float, authority_time: float) -> void:
	var contributor_counts: Dictionary = {}
	for peer_key: Variant in revive_target_by_peer.keys():
		var peer_id: int = int(peer_key)
		if float(interact_intent_until.get(peer_id, 0.0)) < authority_time:
			continue
		var reviver := players_by_peer.get(peer_id) as CrewPlayer
		var target := players_by_peer.get(int(revive_target_by_peer[peer_id])) as CrewPlayer
		if reviver == null or target == null or _find_revive_target(reviver) != target:
			continue
		contributor_counts[target.peer_id] = mini(MAX_REVIVE_CONTRIBUTORS, int(contributor_counts.get(target.peer_id, 0)) + 1)
	for target_key: Variant in contributor_counts:
		var target := players_by_peer.get(int(target_key)) as CrewPlayer
		if target.authority_add_revive_progress(delta * float(contributor_counts[target_key])):
			revives_confirmed += 1


func _find_revive_target(reviver: CrewPlayer) -> CrewPlayer:
	var closest: CrewPlayer
	var closest_distance: float = reviver.definition.revive_interaction_range_px
	for peer_key: Variant in players_by_peer:
		var candidate := players_by_peer[peer_key] as CrewPlayer
		if candidate == reviver or not candidate.survival.is_downed:
			continue
		var distance: float = reviver.position.distance_to(candidate.position)
		if distance <= closest_distance:
			closest = candidate
			closest_distance = distance
	return closest


func _clear_peer_intent(peer_id: int) -> void:
	revive_target_by_peer.erase(peer_id)
	interact_intent_until.erase(peer_id)
