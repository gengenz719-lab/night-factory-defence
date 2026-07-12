extends Node2D

enum MeasureState { WARMUP, SAMPLE, DONE }

const VIEW_SIZE := Vector2(1920.0, 1080.0)
const DEFAULT_WARMUP_SECONDS: float = 2.0
const DEFAULT_SAMPLE_SECONDS: float = 8.0
const PARTICLES_PER_EMITTER: int = 256
const PARTICLE_EMITTER_COUNT: int = 4
const LIGHT_COUNT: int = 8
const WORKLOADS: Array[Dictionary] = [
	{"name": "scale_25", "enemies": 15, "player_bullets": 20, "vehicle_bullets": 20, "enemy_bullets": 15, "layers": 5, "particles": 1024, "lights": 8},
	{"name": "scale_50", "enemies": 30, "player_bullets": 40, "vehicle_bullets": 40, "enemy_bullets": 30, "layers": 5, "particles": 1024, "lights": 8},
	{"name": "full_no_particles", "enemies": 60, "player_bullets": 80, "vehicle_bullets": 80, "enemy_bullets": 60, "layers": 5, "particles": 0, "lights": 8},
	{"name": "full_3_layers", "enemies": 60, "player_bullets": 80, "vehicle_bullets": 80, "enemy_bullets": 60, "layers": 3, "particles": 1024, "lights": 8},
	{"name": "full_no_lights", "enemies": 60, "player_bullets": 80, "vehicle_bullets": 80, "enemy_bullets": 60, "layers": 5, "particles": 1024, "lights": 0},
	{"name": "full", "enemies": 60, "player_bullets": 80, "vehicle_bullets": 80, "enemy_bullets": 60, "layers": 5, "particles": 1024, "lights": 8},
]

var visual_pool := SpikeVisualPool.new()
var background_layers: Array[Parallax2D] = []
var particle_emitters: Array[GPUParticles2D] = []
var lights: Array[PointLight2D] = []
var status_label: Label
var stage_index: int = -1
var state: MeasureState = MeasureState.DONE
var stage_elapsed: float = 0.0
var frame_times: Array[float] = []
var results: Array[Dictionary] = []
var warmup_seconds: float = DEFAULT_WARMUP_SECONDS
var sample_seconds: float = DEFAULT_SAMPLE_SECONDS
var output_path: String = "res://results/render_load_results.json"


func _ready() -> void:
	_parse_arguments()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_backgrounds()
	_build_vehicle_silhouette()
	_build_visual_pool()
	_build_particles()
	_build_lights()
	_build_hud()
	call_deferred(&"_start_next_stage")


func _process(delta: float) -> void:
	if state == MeasureState.DONE:
		return
	stage_elapsed += delta
	if state == MeasureState.WARMUP:
		if stage_elapsed >= warmup_seconds:
			state = MeasureState.SAMPLE
			stage_elapsed = 0.0
			frame_times.clear()
	elif state == MeasureState.SAMPLE:
		frame_times.append(delta)
		if stage_elapsed >= sample_seconds:
			_finish_stage()
	_update_hud()


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--quick":
			warmup_seconds = 0.3
			sample_seconds = 0.7
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")


func _build_backgrounds() -> void:
	for index: int in 5:
		var layer := Parallax2D.new()
		layer.name = "BackgroundLayer%d" % (index + 1)
		layer.scroll_scale = Vector2(0.08 + float(index) * 0.12, 1.0)
		layer.repeat_size = Vector2(1920.0, 0.0)
		layer.repeat_times = 3
		layer.autoscroll = Vector2(-8.0 - float(index) * 22.0, 0.0)
		layer.z_index = -100 + index
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/background_%02d.svg" % (index + 1)) as Texture2D
		sprite.position = VIEW_SIZE * 0.5
		layer.add_child(sprite)
		add_child(layer)
		background_layers.append(layer)


func _build_vehicle_silhouette() -> void:
	var vehicle := Polygon2D.new()
	vehicle.polygon = PackedVector2Array([
		Vector2(430, 470), Vector2(1320, 470), Vector2(1450, 610),
		Vector2(1410, 820), Vector2(380, 820), Vector2(340, 620),
	])
	vehicle.color = Color("#27323d")
	vehicle.z_index = -5
	add_child(vehicle)
	for y_value: float in [555.0, 700.0]:
		var floor_line := Line2D.new()
		floor_line.points = PackedVector2Array([Vector2(430, y_value), Vector2(1370, y_value)])
		floor_line.width = 8.0
		floor_line.default_color = Color("#7f8f92")
		floor_line.z_index = -4
		add_child(floor_line)


func _build_visual_pool() -> void:
	add_child(visual_pool)
	var world := Node2D.new()
	world.name = "PooledVisuals"
	add_child(world)
	visual_pool.setup(world, _solid_texture(Vector2i(58, 72)), _solid_texture(Vector2i(22, 7)))


func _build_particles() -> void:
	var particle_texture: Texture2D = _solid_texture(Vector2i(8, 8))
	for index: int in PARTICLE_EMITTER_COUNT:
		var emitter := GPUParticles2D.new()
		emitter.name = "ImpactEmitter%d" % (index + 1)
		emitter.amount = PARTICLES_PER_EMITTER
		emitter.lifetime = 1.2
		emitter.randomness = 0.35
		emitter.fixed_fps = 60
		emitter.position = Vector2(520.0 + float(index) * 310.0, 470.0 + float(index % 2) * 260.0)
		emitter.texture = particle_texture
		var material := ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = 85.0
		material.direction = Vector3(0.0, -1.0, 0.0)
		material.spread = 180.0
		material.initial_velocity_min = 80.0
		material.initial_velocity_max = 260.0
		material.gravity = Vector3(0.0, 280.0, 0.0)
		material.scale_min = 0.35
		material.scale_max = 1.4
		material.color = [Color("#ffcc66"), Color("#ff6b55"), Color("#d8f3ff"), Color("#8792a8")][index]
		emitter.process_material = material
		emitter.emitting = true
		add_child(emitter)
		particle_emitters.append(emitter)


func _build_lights() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 0.78, 0.48, 0.82), Color(1, 0.35, 0.18, 0.0)])
	var light_texture := GradientTexture2D.new()
	light_texture.gradient = gradient
	light_texture.width = 256
	light_texture.height = 256
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	for index: int in LIGHT_COUNT:
		var light := PointLight2D.new()
		light.texture = light_texture
		light.energy = 1.15
		light.texture_scale = 1.8
		light.position = Vector2(470.0 + float(index % 4) * 285.0, 535.0 + float(index / 4) * 185.0)
		add_child(light)
		lights.append(light)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var panel := ColorRect.new()
	panel.position = Vector2(20, 20)
	panel.size = Vector2(720, 155)
	panel.color = Color(0.02, 0.03, 0.05, 0.88)
	canvas.add_child(panel)
	status_label = Label.new()
	status_label.position = Vector2(40, 35)
	status_label.size = Vector2(680, 125)
	status_label.add_theme_font_size_override(&"font_size", 24)
	canvas.add_child(status_label)


func _solid_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _start_next_stage() -> void:
	stage_index += 1
	if stage_index >= WORKLOADS.size():
		_write_report_and_quit()
		return
	var workload: Dictionary = WORKLOADS[stage_index]
	visual_pool.set_active_counts(
		int(workload["enemies"]), int(workload["player_bullets"]),
		int(workload["vehicle_bullets"]), int(workload["enemy_bullets"])
	)
	for index: int in background_layers.size():
		background_layers[index].visible = index < int(workload["layers"])
	var particles_enabled: bool = int(workload["particles"]) > 0
	for emitter: GPUParticles2D in particle_emitters:
		emitter.emitting = particles_enabled
		emitter.visible = particles_enabled
	for index: int in lights.size():
		lights[index].enabled = index < int(workload["lights"])
	state = MeasureState.WARMUP
	stage_elapsed = 0.0
	frame_times.clear()
	print("SPIKE_C_STAGE_START %s" % workload["name"])


func _finish_stage() -> void:
	var workload: Dictionary = WORKLOADS[stage_index]
	var frame_total: float = 0.0
	var maximum_frame: float = 0.0
	for frame_time: float in frame_times:
		frame_total += frame_time
		maximum_frame = maxf(maximum_frame, frame_time)
	var sorted_times: Array[float] = frame_times.duplicate()
	sorted_times.sort()
	sorted_times.reverse()
	var worst_count: int = maxi(1, ceili(float(sorted_times.size()) * 0.01))
	var worst_total: float = 0.0
	for index: int in worst_count:
		worst_total += sorted_times[index]
	var result: Dictionary = workload.duplicate()
	result["total_bullets"] = int(workload["player_bullets"]) + int(workload["vehicle_bullets"]) + int(workload["enemy_bullets"])
	result["sample_seconds"] = frame_total
	result["sample_frames"] = frame_times.size()
	result["average_fps"] = float(frame_times.size()) / maxf(frame_total, 0.000001)
	result["one_percent_low_fps"] = 1.0 / maxf(worst_total / float(worst_count), 0.000001)
	result["maximum_frame_time_ms"] = maximum_frame * 1000.0
	result["pool_reuses_total"] = visual_pool.total_reuses()
	results.append(result)
	print("SPIKE_C_STAGE_RESULT %s avg=%.2f low=%.2f max_ms=%.3f frames=%d" % [
		result["name"], result["average_fps"], result["one_percent_low_fps"],
		result["maximum_frame_time_ms"], result["sample_frames"],
	])
	state = MeasureState.DONE
	call_deferred(&"_start_next_stage")


func _update_hud() -> void:
	if status_label == null or stage_index < 0 or stage_index >= WORKLOADS.size():
		return
	var workload: Dictionary = WORKLOADS[stage_index]
	var phase_name: String = "WARMUP" if state == MeasureState.WARMUP else "MEASURE"
	status_label.text = "SPIKE C — %s / %s\n敵 %d  弾 %d+%d+%d  背景 %d  粒子 %d  Light %d\nFPS %d   経過 %.1f秒 / %.1f秒   Pool再利用 %d" % [
		workload["name"], phase_name, workload["enemies"], workload["player_bullets"],
		workload["vehicle_bullets"], workload["enemy_bullets"], workload["layers"],
		workload["particles"], workload["lights"], Engine.get_frames_per_second(),
		stage_elapsed, warmup_seconds if state == MeasureState.WARMUP else sample_seconds,
		visual_pool.total_reuses(),
	]


func _write_report_and_quit() -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var report: Dictionary = {
		"schema_version": 1,
		"timestamp_utc": Time.get_datetime_string_from_system(true, true),
		"engine": Engine.get_version_info(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"machine": {
			"os": OS.get_name(),
			"os_version": OS.get_version(),
			"cpu": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
			"screen_width": screen_size.x,
			"screen_height": screen_size.y,
		},
		"measurement": {
			"window_width": 1920,
			"window_height": 1080,
			"vsync": false,
			"warmup_seconds_per_stage": warmup_seconds,
			"sample_seconds_per_stage": sample_seconds,
		},
		"pool_capacity": {
			"enemies": SpikeVisualPool.MAX_ENEMIES,
			"player_bullets": SpikeVisualPool.MAX_PLAYER_BULLETS,
			"vehicle_bullets": SpikeVisualPool.MAX_VEHICLE_BULLETS,
			"enemy_bullets": SpikeVisualPool.MAX_ENEMY_BULLETS,
		},
		"stages": results,
	}
	var absolute_output: String = ProjectSettings.globalize_path(output_path) if output_path.begins_with("res://") or output_path.begins_with("user://") else output_path
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file := FileAccess.open(absolute_output, FileAccess.WRITE)
	if file == null:
		push_error("結果JSONを書き込めません: %s" % absolute_output)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var full_result: Dictionary = results.back()
	print("SPIKE_C_COMPLETE path=%s full_avg=%.2f full_low=%.2f full_max_ms=%.3f" % [
		absolute_output, full_result["average_fps"], full_result["one_percent_low_fps"],
		full_result["maximum_frame_time_ms"],
	])
	get_tree().quit(0)
