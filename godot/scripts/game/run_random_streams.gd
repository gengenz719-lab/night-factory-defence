class_name RunRandomStreams
extends RefCounted

const ROUTE_SALT: int = 0x13579BDF
const WAVE_SALT: int = 0x2468ACE0
const REWARD_SALT: int = 0x31415926
const EVENT_SALT: int = 0x27182818
const VISUAL_SALT: int = 0x5A17C0DE

var route := RandomNumberGenerator.new()
var wave := RandomNumberGenerator.new()
var reward := RandomNumberGenerator.new()
var event := RandomNumberGenerator.new()
var visual := RandomNumberGenerator.new()


func setup(run_seed: int) -> void:
	route.seed = run_seed ^ ROUTE_SALT
	wave.seed = run_seed ^ WAVE_SALT
	reward.seed = run_seed ^ REWARD_SALT
	event.seed = run_seed ^ EVENT_SALT
	visual.seed = run_seed ^ VISUAL_SALT
