class_name VoteController
extends Node

signal vote_started(kind: VoteKind)
signal vote_changed(kind: VoteKind)
signal vote_resolved(kind: VoteKind, choice_index: int)

enum VoteKind { NONE, RELIC, ROUTE }

var coordinator: RunCoordinator
var rules: VoteRulesDefinition
var reward_random: RandomNumberGenerator
var route_random: RandomNumberGenerator
var active_kind: VoteKind = VoteKind.NONE
var choice_count: int = 0
var remaining_time: float = 0.0
var eligible_peer_ids: Array[int] = []
var votes_by_peer: Dictionary = {}
var choice_counts: PackedInt32Array = PackedInt32Array()
var resolved_votes: int = 0
var tie_breaks: int = 0


func setup(run: RunCoordinator, vote_rules: VoteRulesDefinition, reward_stream: RandomNumberGenerator, route_stream: RandomNumberGenerator) -> void:
	coordinator = run
	rules = vote_rules
	reward_random = reward_stream
	route_random = route_stream


func _process(delta: float) -> void:
	if active_kind == VoteKind.NONE:
		return
	remaining_time = maxf(0.0, remaining_time - delta)
	if NetworkSession.is_host_authority() and remaining_time <= 0.0:
		_resolve_vote()


func start_vote(kind: VoteKind, number_of_choices: int) -> void:
	if not NetworkSession.is_host_authority() or kind == VoteKind.NONE or number_of_choices <= 0:
		return
	active_kind = kind
	choice_count = number_of_choices
	remaining_time = rules.vote_duration_seconds
	eligible_peer_ids = NetworkSession.connected_peer_ids()
	votes_by_peer.clear()
	choice_counts = PackedInt32Array()
	choice_counts.resize(choice_count)
	vote_started.emit(kind)
	_receive_vote_started.rpc(kind, choice_count, remaining_time)


func request_vote(choice_index: int) -> void:
	if active_kind == VoteKind.NONE:
		return
	if NetworkSession.is_host_authority():
		_record_vote(NetworkSession.local_peer_id(), choice_index)
	else:
		_submit_vote.rpc_id(NetworkSession.HOST_PEER_ID, active_kind, choice_index)


func vote_count_text() -> String:
	var parts := PackedStringArray()
	for index: int in choice_counts.size():
		parts.append("%d:%d票" % [index + 1, choice_counts[index]])
	return "  ".join(parts)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_vote(kind: int, choice_index: int) -> void:
	if not NetworkSession.is_host_authority() or kind != active_kind:
		return
	_record_vote(multiplayer.get_remote_sender_id(), choice_index)


func _record_vote(peer_id: int, choice_index: int) -> void:
	if active_kind == VoteKind.NONE or peer_id not in eligible_peer_ids or choice_index < 0 or choice_index >= choice_count:
		return
	votes_by_peer[peer_id] = choice_index
	_recount_votes()
	vote_changed.emit(active_kind)
	_receive_vote_snapshot.rpc(active_kind, choice_counts, remaining_time)
	if eligible_peer_ids.size() <= 1 or _has_strict_majority():
		_resolve_vote()


func _recount_votes() -> void:
	choice_counts.fill(0)
	for choice: Variant in votes_by_peer.values():
		choice_counts[int(choice)] += 1


func _has_strict_majority() -> bool:
	for count: int in choice_counts:
		if count > eligible_peer_ids.size() / 2.0:
			return true
	return false


func _resolve_vote() -> void:
	if active_kind == VoteKind.NONE:
		return
	_recount_votes()
	var highest_count: int = 0
	var tied_choices: Array[int] = []
	for index: int in choice_count:
		var count: int = choice_counts[index]
		if count > highest_count:
			highest_count = count
			tied_choices = [index]
		elif count == highest_count:
			tied_choices.append(index)
	if tied_choices.is_empty():
		for index: int in choice_count:
			tied_choices.append(index)
	var random_stream: RandomNumberGenerator = reward_random if active_kind == VoteKind.RELIC else route_random
	var selected_index: int = tied_choices[0]
	if tied_choices.size() > 1:
		tie_breaks += 1
		selected_index = tied_choices[random_stream.randi_range(0, tied_choices.size() - 1)]
	var resolved_kind: VoteKind = active_kind
	active_kind = VoteKind.NONE
	remaining_time = 0.0
	resolved_votes += 1
	_receive_vote_resolved.rpc(resolved_kind, selected_index)
	vote_resolved.emit(resolved_kind, selected_index)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_vote_started(kind: int, number_of_choices: int, duration: float) -> void:
	if NetworkSession.is_host_authority():
		return
	active_kind = kind as VoteKind
	choice_count = number_of_choices
	remaining_time = duration
	votes_by_peer.clear()
	choice_counts = PackedInt32Array()
	choice_counts.resize(choice_count)
	vote_started.emit(active_kind)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_vote_snapshot(kind: int, counts: PackedInt32Array, time_left: float) -> void:
	if NetworkSession.is_host_authority() or kind != active_kind:
		return
	choice_counts = counts
	remaining_time = time_left
	vote_changed.emit(active_kind)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_vote_resolved(kind: int, choice_index: int) -> void:
	if NetworkSession.is_host_authority():
		return
	active_kind = VoteKind.NONE
	remaining_time = 0.0
	vote_resolved.emit(kind as VoteKind, choice_index)
