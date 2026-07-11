class_name NetworkTestDriver
extends Node

var coordinator: RunCoordinator
enum TestPhase {
	WAIT_MODULE_INTENT,
	WAIT_INVASION,
	WAIT_ACTIONS,
	DOWN_HOST,
	REVIVE_HOST,
	WAIT_DEPARTURE,
	WAIT_RETURN,
	VERIFY_COMBAT,
	PREPARE_WAVE_TWO,
	FINISH_WAVE_TWO,
	WAIT_CLIENT_REPORT,
	COMPLETE,
}

const PHASE_TIMEOUT_SECONDS: float = 15.0

var phase: TestPhase = TestPhase.WAIT_MODULE_INTENT
var phase_elapsed: float = 0.0
var active: bool = false
var replicator: PlayerNetReplicator
var state_replicator: NetStateReplicator
var saw_remote_movement: bool = false
var saw_enemy_snapshot: bool = false
var saw_vehicle_damage: bool = false
var saw_vehicle_repair: bool = false
var saw_wave_two: bool = false
var saw_victory: bool = false
var _initial_remote_position: Vector2 = Vector2.ZERO
var _lowest_front_hp: float = INF
var saw_dodge_state: bool = false
var saw_downed_state: bool = false
var saw_revived_state: bool = false
var saw_departed_state: bool = false
var saw_returned_state: bool = false
var dodge_authority_pass: bool = false
var down_duration_pass: bool = false
var revive_authority_pass: bool = false
var return_authority_pass: bool = false
var character_selection_pass: bool = false
var ability_authority_pass: bool = false
var saw_ability_state: bool = false
var _supplies_before_drone: float = 0.0
var module_layout_authority_pass: bool = false
var power_priority_pass: bool = false
var repair_cap_pass: bool = false
var repair_full_pass: bool = false
var turret_authority_pass: bool = false
var saw_module_layout: bool = false
var saw_power_shutdown: bool = false
var saw_turret_overheat: bool = false
var saw_turret_recovery: bool = false
var _test_turret_id: int = 0
var _client_place_sent: bool = false
var _turret_target_spawned: bool = false
var _client_ready_sent: bool = false
var _client_shot_acknowledged: bool = false
var _client_shot_ack_sent: bool = false
var _client_observations_ready: bool = false
var _client_wave_two_acknowledged: bool = false
var breach_authority_pass: bool = false
var invasion_authority_pass: bool = false
var module_attack_authority_pass: bool = false
var breach_seal_authority_pass: bool = false
var saw_breach_open: bool = false
var saw_breach_closed: bool = false
var saw_invasion_warning: bool = false
var saw_enemy_inside: bool = false
var saw_invader_module_damage: bool = false
var _client_invasion_acknowledged: bool = false
var _client_invasion_ack_sent: bool = false
var _test_climber: EnemyUnit
var _workbench_instance_id: int = 0
var _supplies_before_breach_seal: float = -1.0
var relic_vote_authority_pass: bool = false
var route_vote_authority_pass: bool = false
var route_effect_authority_pass: bool = false
var saw_same_relic_choices: bool = false
var saw_relic_result: bool = false
var saw_same_route_choices: bool = false
var saw_route_result: bool = false
var saw_route_reward: bool = false
var _client_relic_vote_sent: bool = false
var _client_route_vote_sent: bool = false
var _host_relic_vote_sent: bool = false
var _host_route_vote_sent: bool = false
var _expected_relic_id: StringName = &""


func setup(run: RunCoordinator) -> void:
	coordinator = run
	replicator = coordinator.player_net_replicator
	state_replicator = coordinator.net_state_replicator
	active = OS.get_cmdline_user_args().has("--network-test-host") or OS.get_cmdline_user_args().has("--network-test-client")
	if not active:
		return
	replicator.remote_player_snapshot_received.connect(_on_remote_player_snapshot)
	state_replicator.enemy_snapshot_received.connect(func() -> void: saw_enemy_snapshot = true)
	state_replicator.vehicle_snapshot_received.connect(_on_vehicle_snapshot)
	state_replicator.run_state_received.connect(_on_run_state)
	state_replicator.breach_snapshot_received.connect(_on_breach_snapshot)
	state_replicator.enemy_invasion_snapshot_received.connect(_on_enemy_invasion_snapshot)
	state_replicator.reward_choices_received.connect(_on_reward_choices_received)
	state_replicator.relic_selected_received.connect(func(_relic_id: StringName) -> void: saw_relic_result = true)
	state_replicator.route_choices_received.connect(_on_route_choices_received)
	state_replicator.route_selected_received.connect(func(_route_id: StringName) -> void: saw_route_result = true)
	state_replicator.route_reward_received.connect(func() -> void: saw_route_reward = true)
	coordinator.module_net_replicator.module_state_received.connect(_on_module_state_received)
	replicator.player_survival_snapshot_received.connect(_on_player_survival_snapshot)
	replicator.player_ability_snapshot_received.connect(_on_player_ability_snapshot)
	var host_player := coordinator.players_by_peer.get(NetworkSession.HOST_PEER_ID) as CrewPlayer
	var client_player: CrewPlayer = _find_client_player()
	character_selection_pass = host_player != null and client_player != null and host_player.definition.id == &"character_gunner" and client_player.definition.id == &"character_engineer"
	_workbench_instance_id = coordinator.module_system.workbench_module().instance_id
	for peer_key: Variant in coordinator.players_by_peer:
		if int(peer_key) != NetworkSession.local_peer_id():
			_initial_remote_position = (coordinator.players_by_peer[peer_key] as CrewPlayer).position


func _process(delta: float) -> void:
	if not active:
		return
	if not NetworkSession.is_host_authority():
		_drive_client_votes()
		if not _client_place_sent and coordinator.stage_director.state == StageDirector.RunState.PREPARE and coordinator.module_system.modules.size() == 4:
			_client_place_sent = true
			coordinator.module_net_replicator.request_place(&"module_firing_port", Vector2i(1, 1))
		_observe_client_modules()
		_try_acknowledge_shot_observation()
		_try_acknowledge_invasion_observations()
		_try_acknowledge_client_observations()
		return
	phase_elapsed += delta
	if phase_elapsed >= PHASE_TIMEOUT_SECONDS:
		_timeout_current_phase()
		return
	var host_player := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
	var client_player: CrewPlayer = _find_client_player()
	match phase:
		TestPhase.WAIT_MODULE_INTENT:
			if coordinator.module_net_replicator.remote_place_intents_received > 0 and coordinator.module_system.modules.size() == 5:
				coordinator.module_system.scrap = 300
				coordinator.module_net_replicator.request_place(&"module_turret", Vector2i(2, 0))
				_test_turret_id = coordinator.module_system.next_instance_id - 1
				coordinator.module_net_replicator.request_place(&"module_turret", Vector2i(4, 0))
				var second_turret_id: int = coordinator.module_system.next_instance_id - 1
				var workbench: VehicleModuleState = coordinator.module_system.active_workbench()
				coordinator.module_net_replicator.request_priority(workbench.instance_id, 3)
				coordinator.module_net_replicator.request_priority(_test_turret_id, 2)
				coordinator.module_net_replicator.request_priority(second_turret_id, 1)
				var second_turret: VehicleModuleState = coordinator.module_system.modules[second_turret_id]
				module_layout_authority_pass = coordinator.module_system.modules.size() == 7 and coordinator.module_net_replicator.remote_place_intents_received > 0
				power_priority_pass = workbench.powered and (coordinator.module_system.modules[_test_turret_id] as VehicleModuleState).powered and not second_turret.powered
				var test_turret: VehicleModuleState = coordinator.module_system.modules[_test_turret_id]
				test_turret.heat = test_turret.definition.heat_limit
				test_turret.overheated = true
				test_turret.overheat_time = test_turret.definition.overheat_stop_seconds
				coordinator.stage_director.begin_combat()
				var enemy: EnemyUnit = coordinator.enemy_director.spawn_enemy()
				if enemy != null:
					enemy.position = Vector2(700.0, 600.0)
				coordinator.vehicle_state.take_attack(&"front", 170.0)
				coordinator.vehicle_state.take_attack(&"roof", float(coordinator.vehicle_state.max_section_hp[&"roof"]))
				breach_authority_pass = coordinator.vehicle_state.is_breached(&"roof")
				_test_climber = coordinator.enemy_director.spawn_test_enemy(GameCatalog.get_definition(&"enemy_climber") as EnemyDefinition)
				_test_climber.max_hp = 9999.0
				_test_climber.hp = 9999.0
				_test_climber.position = Vector2(SurvivalVehicle.LADDER_X, SurvivalVehicle.ROOF_FLOOR_Y - 15.0)
				_supplies_before_drone = coordinator.vehicle_state.supplies
				_advance_phase(TestPhase.WAIT_INVASION)
		TestPhase.WAIT_INVASION:
			_drive_and_latch_actions(host_player, client_player)
			invasion_authority_pass = coordinator.enemy_director.invasions_confirmed > 0 and _test_climber.inside_vehicle
			module_attack_authority_pass = coordinator.enemy_director.module_attacks_confirmed > 0 and coordinator.module_system.workbench_module().hp < coordinator.module_system.workbench_module().definition.max_hp
			if breach_authority_pass and invasion_authority_pass and module_attack_authority_pass and _client_invasion_acknowledged:
				_test_climber.queue_free()
				_advance_phase(TestPhase.WAIT_ACTIONS)
		TestPhase.WAIT_ACTIONS:
			_drive_and_latch_actions(host_player, client_player)
			if ability_authority_pass and dodge_authority_pass and _client_shot_acknowledged:
				_advance_phase(TestPhase.DOWN_HOST)
		TestPhase.DOWN_HOST:
			if host_player.survival.invulnerable_time <= 0.0:
				client_player.position = host_player.position + Vector2(50.0, 0.0)
				host_player.take_damage(9999.0)
				down_duration_pass = (
					host_player.survival.is_downed and
					is_equal_approx(host_player.survival.downed_time, host_player.definition.downed_grace_seconds)
				)
				if down_duration_pass:
					_advance_phase(TestPhase.REVIVE_HOST)
		TestPhase.REVIVE_HOST:
			var revive_range: float = client_player.definition.revive_interaction_range_px
			if host_player.position.distance_to(client_player.position) > revive_range * 0.8:
				client_player.position = host_player.position + Vector2(revive_range * 0.5, 0.0)
			_drive_intent(client_player.peer_id, false, host_player.survival.is_downed, false)
			if not host_player.survival.is_downed:
				revive_authority_pass = (
					coordinator.revive_controller.revives_confirmed > 0 and
					is_equal_approx(host_player.survival.hp, host_player.survival.max_hp * host_player.definition.revive_health_ratio) and
					host_player.survival.invulnerable_time > 0.0
				)
				client_player.survival.invulnerable_time = 0.0
				client_player.take_damage(9999.0)
				down_duration_pass = down_duration_pass and is_equal_approx(client_player.survival.downed_time, client_player.definition.downed_grace_seconds)
				client_player.survival.downed_time = 0.25
				if revive_authority_pass and client_player.survival.is_downed:
					_advance_phase(TestPhase.WAIT_DEPARTURE)
		TestPhase.WAIT_DEPARTURE:
			if client_player.survival.is_departed:
				return_authority_pass = absf(client_player.survival.return_time - client_player.definition.return_wait_seconds) <= 0.1
				client_player.survival.return_time = 0.25
				_advance_phase(TestPhase.WAIT_RETURN)
		TestPhase.WAIT_RETURN:
			if not client_player.survival.is_departed and not client_player.survival.is_downed:
				return_authority_pass = return_authority_pass and is_equal_approx(
					client_player.survival.hp,
					client_player.survival.max_hp * client_player.definition.return_health_ratio
				)
				if return_authority_pass:
					_advance_phase(TestPhase.VERIFY_COMBAT)
		TestPhase.VERIFY_COMBAT:
			_drive_intent(NetworkSession.HOST_PEER_ID, false, false, false, Vector2.RIGHT)
			if not _turret_target_spawned:
				_turret_target_spawned = true
				var turret_target: EnemyUnit = coordinator.enemy_director.spawn_test_enemy(GameCatalog.get_definition(&"enemy_walker") as EnemyDefinition)
				turret_target.position = Vector2(700.0, 600.0)
			var repairer := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
			repairer.position = SurvivalVehicle.REPAIR_CONSOLE
			coordinator.vehicle_state.repair_at(repairer.position, delta, 1.0)
			var combat_cap: float = float(coordinator.vehicle_state.max_section_hp[&"front"]) * coordinator.vehicle_state.definition.combat_repair_cap_ratio
			repair_cap_pass = is_equal_approx(float(coordinator.vehicle_state.section_hp[&"front"]), combat_cap)
			var test_turret: VehicleModuleState = coordinator.module_system.modules[_test_turret_id]
			turret_authority_pass = coordinator.module_system.turret_shots > 0 and not test_turret.overheated and test_turret.heat < test_turret.definition.heat_limit
			if repair_cap_pass and turret_authority_pass:
				coordinator.stage_director.finish_wave()
				_advance_phase(TestPhase.PREPARE_WAVE_TWO)
		TestPhase.PREPARE_WAVE_TWO:
			if coordinator.stage_director.state == StageDirector.RunState.REWARD:
				if coordinator.vote_controller.active_kind == VoteController.VoteKind.RELIC and coordinator.active_relic_choices.size() == 3 and not _host_relic_vote_sent:
					_host_relic_vote_sent = true
					_expected_relic_id = coordinator.active_relic_choices[1].id
					coordinator.select_relic(1)
				if coordinator.vote_controller.active_kind == VoteController.VoteKind.ROUTE and coordinator.active_route_choices.size() == 2:
					relic_vote_authority_pass = coordinator.reward_system.acquired.size() == 1 and coordinator.reward_system.acquired[0].id == _expected_relic_id
					if not _host_route_vote_sent:
						_host_route_vote_sent = true
						coordinator.select_route(0)
					if coordinator.vote_controller.votes_by_peer.size() >= 2:
						coordinator.vote_controller.remaining_time = 0.0
			if coordinator.selected_route != null:
				route_vote_authority_pass = coordinator.vote_controller.tie_breaks > 0 and coordinator.selected_route in coordinator.active_route_choices
			if _supplies_before_breach_seal < 0.0:
				_supplies_before_breach_seal = coordinator.vehicle_state.supplies
			var repairer := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
			repairer.position = SurvivalVehicle.REPAIR_CONSOLE
			coordinator.vehicle_state.repair_at(repairer.position, delta, 1.0)
			if not coordinator.vehicle_state.is_breached(&"roof"):
				breach_seal_authority_pass = coordinator.vehicle_state.supplies <= _supplies_before_breach_seal - coordinator.vehicle_state.definition.breach_seal_supply_cost
			repair_full_pass = is_equal_approx(float(coordinator.vehicle_state.section_hp[&"front"]), float(coordinator.vehicle_state.max_section_hp[&"front"]))
			if repair_full_pass and breach_seal_authority_pass and relic_vote_authority_pass and route_vote_authority_pass and coordinator.stage_director.state == StageDirector.RunState.PREPARE:
				coordinator.stage_director.begin_combat()
				var expected_budget: int = roundi(float(coordinator.stage_director.current_wave().threat_budget) * coordinator.selected_route.enemy_budget_multiplier)
				route_effect_authority_pass = coordinator.enemy_director.remaining_budget == expected_budget
				_advance_phase(TestPhase.FINISH_WAVE_TWO)
		TestPhase.FINISH_WAVE_TWO:
			if _client_wave_two_acknowledged and coordinator.stage_director.state == StageDirector.RunState.COMBAT:
				coordinator.stage_director.finish_wave()
				_advance_phase(TestPhase.WAIT_CLIENT_REPORT)
		TestPhase.WAIT_CLIENT_REPORT:
			if _client_observations_ready and coordinator.stage_director.state == StageDirector.RunState.VICTORY:
				_request_network_test_report()
				_advance_phase(TestPhase.COMPLETE)
		TestPhase.COMPLETE:
			pass


func _drive_intent(peer_id: int, wants_dodge: bool, wants_interact: bool, wants_ability: bool, axis: Vector2 = Vector2.ZERO, wants_fire: bool = false) -> void:
	var sequence: int = int(replicator.last_processed_input.get(peer_id, 0)) + 1
	if peer_id != NetworkSession.HOST_PEER_ID and wants_dodge:
		replicator.remote_dodge_intents_received += 1
	replicator._apply_host_input(
		peer_id, sequence, axis, Vector2.RIGHT,
		wants_fire, wants_interact, wants_dodge, wants_ability
	)


func _drive_and_latch_actions(host_player: CrewPlayer, client_player: CrewPlayer) -> void:
	var abilities_ready: bool = replicator.abilities_confirmed >= 2
	var dodges_ready: bool = (
		replicator.remote_dodge_intents_received > 0 and
		replicator.dodges_confirmed >= 2 and
		client_player.survival.invulnerable_time > 0.0
	)
	_drive_intent(NetworkSession.HOST_PEER_ID, not dodge_authority_pass and not dodges_ready, false, not ability_authority_pass and not abilities_ready, Vector2.ZERO, not _client_shot_acknowledged)
	_drive_intent(client_player.peer_id, not dodge_authority_pass and not dodges_ready, false, not ability_authority_pass and not abilities_ready, Vector2.ZERO, not _client_shot_acknowledged)
	if not ability_authority_pass and abilities_ready:
		ability_authority_pass = (
			host_player.ability_active_time > 0.0 and client_player.ability_active_time > 0.0 and
			host_player.effective_fire_interval() < 1.0 / host_player.weapon_definition.shots_per_second and
			float(coordinator.vehicle_state.section_hp[&"roof"]) > 0.0 and
			is_equal_approx(coordinator.vehicle_state.supplies, _supplies_before_drone)
		)
	if not dodge_authority_pass and dodges_ready:
		var hp_before: float = client_player.survival.hp
		client_player.take_damage(10.0)
		dodge_authority_pass = is_equal_approx(client_player.survival.hp, hp_before)


func _advance_phase(next_phase: TestPhase) -> void:
	phase = next_phase
	phase_elapsed = 0.0


func _timeout_current_phase() -> void:
	var host_player := coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer
	var client_player: CrewPlayer = _find_client_player()
	print("NETWORK_TEST_TIMEOUT phase=%s phase_elapsed=%.1f ability=%s dodge=%s confirmed=%d/%d revive=%.2f host_down=%s client_down=%s client_departed=%s distance=%.1f intents=%d inputs=%d client_ready=%s" % [
		TestPhase.keys()[phase], phase_elapsed, ability_authority_pass, dodge_authority_pass,
		replicator.abilities_confirmed, replicator.dodges_confirmed, host_player.survival.revive_progress,
		host_player.survival.is_downed, client_player.survival.is_downed,
		client_player.survival.is_departed, host_player.position.distance_to(client_player.position),
		coordinator.revive_controller.revive_target_by_peer.size(), replicator.remote_inputs_received,
		_client_observations_ready,
	])
	get_tree().quit(1)


func _try_acknowledge_client_observations() -> void:
	if _client_ready_sent or not _client_observation_conditions_met():
		return
	_client_ready_sent = true
	_ack_client_observations.rpc_id(NetworkSession.HOST_PEER_ID)


func _drive_client_votes() -> void:
	if coordinator.vote_controller.active_kind == VoteController.VoteKind.RELIC and coordinator.active_relic_choices.size() == 3 and not _client_relic_vote_sent:
		_client_relic_vote_sent = true
		coordinator.select_relic(1)
	elif coordinator.vote_controller.active_kind == VoteController.VoteKind.ROUTE and coordinator.active_route_choices.size() == 2 and not _client_route_vote_sent:
		_client_route_vote_sent = true
		coordinator.select_route(1)


func _try_acknowledge_shot_observation() -> void:
	if _client_shot_ack_sent or replicator.confirmed_shots <= 0:
		return
	_client_shot_ack_sent = true
	_ack_shot_observation.rpc_id(NetworkSession.HOST_PEER_ID)


func _try_acknowledge_invasion_observations() -> void:
	if _client_invasion_ack_sent or not (saw_breach_open and saw_invasion_warning and saw_enemy_inside and saw_invader_module_damage):
		return
	_client_invasion_ack_sent = true
	_ack_invasion_observations.rpc_id(NetworkSession.HOST_PEER_ID)


func _client_observation_conditions_met() -> bool:
	return (
		saw_remote_movement and saw_enemy_snapshot and saw_vehicle_damage and saw_vehicle_repair and
		saw_wave_two and saw_victory and replicator.confirmed_shots > 0 and saw_dodge_state and
		saw_downed_state and saw_revived_state and saw_departed_state and saw_returned_state and
		saw_ability_state and saw_module_layout and saw_power_shutdown and saw_turret_overheat and
		saw_turret_recovery and saw_breach_open and saw_breach_closed and saw_invasion_warning and
		saw_enemy_inside and saw_invader_module_damage and saw_same_relic_choices and
		saw_relic_result and saw_same_route_choices and saw_route_result and saw_route_reward
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func _ack_client_observations() -> void:
	if NetworkSession.is_host_authority():
		_client_observations_ready = true


@rpc("any_peer", "call_remote", "reliable", 0)
func _ack_shot_observation() -> void:
	if NetworkSession.is_host_authority():
		_client_shot_acknowledged = true


@rpc("any_peer", "call_remote", "reliable", 0)
func _ack_wave_two() -> void:
	if NetworkSession.is_host_authority():
		_client_wave_two_acknowledged = true


@rpc("any_peer", "call_remote", "reliable", 0)
func _ack_invasion_observations() -> void:
	if NetworkSession.is_host_authority():
		_client_invasion_acknowledged = true


func _on_remote_player_snapshot(_peer_id: int, position_value: Vector2) -> void:
	if position_value.distance_to(_initial_remote_position) > 4.0:
		saw_remote_movement = true


func _on_vehicle_snapshot(front_hp: float) -> void:
	if front_hp < float(coordinator.vehicle_state.max_section_hp[&"front"]):
		saw_vehicle_damage = true
		_lowest_front_hp = minf(_lowest_front_hp, front_hp)
	if saw_vehicle_damage and front_hp > _lowest_front_hp + 1.0:
		saw_vehicle_repair = true


func _on_breach_snapshot(_front: bool, _rear: bool, roof: bool, _lower: bool) -> void:
	if roof:
		saw_breach_open = true
	elif saw_breach_open:
		saw_breach_closed = true


func _on_enemy_invasion_snapshot(_enemy_net_id: int, inside_vehicle: bool, invasion_state: int) -> void:
	saw_invasion_warning = saw_invasion_warning or invasion_state == EnemyUnit.InvasionState.ENTERING
	saw_enemy_inside = saw_enemy_inside or inside_vehicle


func _on_reward_choices_received(first_id: StringName, second_id: StringName, third_id: StringName) -> void:
	saw_same_relic_choices = (
		coordinator.active_relic_choices.size() == 3 and
		coordinator.active_relic_choices[0].id == first_id and
		coordinator.active_relic_choices[1].id == second_id and
		coordinator.active_relic_choices[2].id == third_id
	)


func _on_route_choices_received(first_id: StringName, second_id: StringName) -> void:
	saw_same_route_choices = (
		coordinator.active_route_choices.size() == 2 and
		coordinator.active_route_choices[0].id == first_id and
		coordinator.active_route_choices[1].id == second_id
	)


func _on_module_state_received(instance_id: int, hp: float) -> void:
	if instance_id == _workbench_instance_id:
		var workbench: VehicleModuleState = coordinator.module_system.modules.get(instance_id) as VehicleModuleState
		if workbench != null and hp < workbench.definition.max_hp:
			saw_invader_module_damage = true


func _on_run_state(state: int, wave_index: int) -> void:
	saw_wave_two = saw_wave_two or wave_index >= 1
	saw_victory = saw_victory or state == StageDirector.RunState.VICTORY
	if not NetworkSession.is_host_authority() and wave_index >= 1:
		_ack_wave_two.rpc_id(NetworkSession.HOST_PEER_ID)


func _on_player_survival_snapshot(_peer_id: int, downed: bool, departed: bool, invulnerability: float, dodge_cooldown: float, hp: float) -> void:
	saw_dodge_state = saw_dodge_state or (invulnerability > 0.0 and dodge_cooldown > 0.0)
	if downed:
		saw_downed_state = true
	if saw_downed_state and not downed and not departed and hp > 0.0:
		saw_revived_state = true
	if departed:
		saw_departed_state = true
	if saw_departed_state and not departed and not downed and hp > 0.0:
		saw_returned_state = true


func _on_player_ability_snapshot(_peer_id: int, active_time: float, cooldown: float) -> void:
	saw_ability_state = saw_ability_state or (active_time > 0.0 and cooldown > 0.0)


func _observe_client_modules() -> void:
	var system: VehicleModuleSystem = coordinator.module_system
	saw_module_layout = saw_module_layout or system.modules.size() == 7
	var has_powered_workbench: bool = false
	var has_stopped_turret: bool = false
	for module: VehicleModuleState in system.modules.values():
		if module.definition.id == &"module_workbench" and module.powered:
			has_powered_workbench = true
		if module.definition.id == &"module_turret" and not module.powered:
			has_stopped_turret = true
		if module.definition.id == &"module_turret" and module.priority == 2 and module.overheated:
			saw_turret_overheat = true
		if saw_turret_overheat and module.definition.id == &"module_turret" and module.priority == 2 and not module.overheated and module.heat <= module.definition.overheat_recovery_heat:
			saw_turret_recovery = true
	saw_power_shutdown = saw_power_shutdown or (has_powered_workbench and has_stopped_turret)


func _request_network_test_report() -> void:
	var host_player := coordinator.players_by_peer.get(NetworkSession.HOST_PEER_ID) as CrewPlayer
	var client_player: CrewPlayer = _find_client_player()
	var client_position: Vector2 = client_player.position if client_player != null else Vector2.ZERO
	var state_hash: String = _state_hash(
		coordinator.stage_director.state, coordinator.stage_director.wave_index,
		coordinator.vehicle_state.hull, float(coordinator.vehicle_state.section_hp[&"front"]),
		coordinator.reward_system.kills, host_player.position, client_position, _module_hash()
	)
	_receive_final_test_state.rpc(
		state_hash, coordinator.stage_director.state, coordinator.stage_director.wave_index,
		coordinator.vehicle_state.hull, float(coordinator.vehicle_state.section_hp[&"front"]),
		coordinator.reward_system.kills, host_player.position, client_position
	)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_final_test_state(host_hash: String, state: int, wave_index: int, hull: float, front: float, kills: int, host_position: Vector2, client_position: Vector2) -> void:
	if NetworkSession.is_host_authority():
		return
	coordinator.apply_stage_snapshot(state, wave_index, 0.0)
	coordinator.vehicle_state.hull = hull
	coordinator.vehicle_state.section_hp[&"front"] = front
	coordinator.reward_system.kills = kills
	(coordinator.players_by_peer[NetworkSession.HOST_PEER_ID] as CrewPlayer).position = host_position
	(coordinator.players_by_peer[NetworkSession.local_peer_id()] as CrewPlayer).position = client_position
	var client_hash: String = _state_hash(state, wave_index, hull, front, kills, host_position, client_position, _module_hash())
	var average_correction: float = replicator.correction_sum / maxf(1.0, float(replicator.correction_count))
	_submit_network_test_report.rpc_id(
		NetworkSession.HOST_PEER_ID,
		saw_remote_movement, saw_enemy_snapshot, saw_vehicle_damage, saw_vehicle_repair,
		saw_wave_two, saw_victory, replicator.confirmed_shots > 0, host_hash == client_hash,
		saw_dodge_state, saw_downed_state, saw_revived_state, saw_departed_state, saw_returned_state,
		saw_ability_state,
		saw_module_layout, saw_power_shutdown, saw_turret_overheat, saw_turret_recovery,
		saw_breach_open, saw_breach_closed, saw_invasion_warning, saw_enemy_inside, saw_invader_module_damage,
		saw_same_relic_choices, saw_relic_result, saw_same_route_choices, saw_route_result, saw_route_reward,
		replicator.max_correction, average_correction
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_network_test_report(
	remote_moved: bool, enemy_synced: bool, vehicle_damaged: bool, vehicle_repaired: bool,
	wave_two: bool, victory: bool, shots_synced: bool, hash_matched: bool,
	dodge_synced: bool, downed_synced: bool, revived_synced: bool, departed_synced: bool, returned_synced: bool,
	ability_synced: bool,
	module_layout_synced: bool, power_synced: bool, overheat_synced: bool, recovery_synced: bool,
	breach_open_synced: bool, breach_closed_synced: bool, invasion_warning_synced: bool, enemy_inside_synced: bool, invader_module_damage_synced: bool,
	relic_choices_synced: bool, relic_result_synced: bool, route_choices_synced: bool, route_result_synced: bool, route_reward_synced: bool,
	client_max_correction: float, client_average_correction: float
) -> void:
	if not NetworkSession.is_host_authority():
		return
	var passed: bool = (
		remote_moved and enemy_synced and vehicle_damaged and vehicle_repaired and
		wave_two and victory and shots_synced and hash_matched and
		dodge_synced and downed_synced and revived_synced and departed_synced and returned_synced and
		ability_synced and character_selection_pass and ability_authority_pass and
		module_layout_synced and power_synced and overheat_synced and recovery_synced and
		breach_open_synced and breach_closed_synced and invasion_warning_synced and enemy_inside_synced and invader_module_damage_synced and
		relic_choices_synced and relic_result_synced and route_choices_synced and route_result_synced and route_reward_synced and
		module_layout_authority_pass and power_priority_pass and repair_cap_pass and repair_full_pass and turret_authority_pass and
		breach_authority_pass and invasion_authority_pass and module_attack_authority_pass and breach_seal_authority_pass and
		relic_vote_authority_pass and route_vote_authority_pass and route_effect_authority_pass and
		dodge_authority_pass and down_duration_pass and revive_authority_pass and return_authority_pass and
		replicator.remote_inputs_received > 0 and replicator.confirmed_shots > 0
	)
	print("NETWORK_TEST_%s inputs=%d shots=%d kills=%d relic_vote=%s route_vote=%s route_effect=%s breach=%s invasion=%s module_attack=%s seal=%s modules=%s power=%s repair=%s turret=%s characters=%s abilities=%s dodge=%s revive=%s return=%s hash=%s max_correction=%.3f avg_correction=%.3f" % [
		"PASS" if passed else "FAIL", replicator.remote_inputs_received, replicator.confirmed_shots,
		coordinator.reward_system.kills, relic_vote_authority_pass, route_vote_authority_pass, route_effect_authority_pass, breach_authority_pass, invasion_authority_pass, module_attack_authority_pass, breach_seal_authority_pass, module_layout_authority_pass, power_priority_pass, repair_cap_pass and repair_full_pass, turret_authority_pass, character_selection_pass, ability_authority_pass, dodge_authority_pass, revive_authority_pass,
		return_authority_pass, hash_matched, client_max_correction, client_average_correction,
	])
	_finish_network_test.rpc(passed)
	call_deferred(&"_quit_host_after_flush", passed)


@rpc("authority", "call_remote", "reliable", 0)
func _finish_network_test(passed: bool) -> void:
	print("NETWORK_CLIENT_%s" % ("PASS" if passed else "FAIL"))
	get_tree().quit(0 if passed else 1)


func _quit_host_after_flush(passed: bool) -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if passed else 1)


func _find_client_player() -> CrewPlayer:
	for peer_key: Variant in coordinator.players_by_peer:
		if int(peer_key) != NetworkSession.HOST_PEER_ID:
			return coordinator.players_by_peer[peer_key] as CrewPlayer
	return null


func _state_hash(state: int, wave_index: int, hull: float, front: float, kills: int, host_position: Vector2, client_position: Vector2, module_hash: String) -> String:
	return str(hash("%d|%d|%.2f|%.2f|%d|%.2f|%.2f|%.2f|%.2f|%s" % [
		state, wave_index, hull, front, kills,
		host_position.x, host_position.y, client_position.x, client_position.y, module_hash,
	]))


func _module_hash() -> String:
	var lines := PackedStringArray()
	var ids: Array[int] = []
	for key: Variant in coordinator.module_system.modules:
		ids.append(int(key))
	ids.sort()
	for instance_id: int in ids:
		var module: VehicleModuleState = coordinator.module_system.modules[instance_id]
		lines.append("%d:%s:%d:%d:%d:%d" % [instance_id, module.definition.id, module.grid_position.x, module.grid_position.y, module.priority, 1 if module.powered else 0])
	var relic_ids := PackedStringArray()
	for relic: RelicDefinition in coordinator.reward_system.acquired:
		relic_ids.append(String(relic.id))
	var route_id: String = String(coordinator.selected_route.id) if coordinator.selected_route != null else ""
	return ",".join(lines) + ":scrap=%d:relics=%s:route=%s" % [coordinator.module_system.scrap, ",".join(relic_ids), route_id]
