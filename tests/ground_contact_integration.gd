extends SceneTree

var checks := 0
var failures: Array[String] = []
var report: Array[String] = []
var scene: Node3D
var camera: Camera3D
const OUT := "res://docs/validation/ground-contact"

class Stage extends Node3D:
	var phase := "playing"
	func is_axis_green(_is_x: bool) -> bool:
		return true

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func sole_minimum(model: Node3D, bare: bool) -> float:
	var low := INF
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name) not in (["FootL", "FootR"] if bare else ["BootL", "BootR"]):
			continue
		var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
		for surface in baked.get_surface_count():
			for vertex in baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				low = minf(low, (mesh.global_transform * vertex).y)
	return low

func snap(name: String, target: Vector3, distance: float = 3.0) -> void:
	camera.position = target + Vector3(distance, 0.4, distance * 0.6)
	camera.look_at(target, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	scene = Stage.new()
	root.add_child(scene)
	CityBuilder._add_environment(scene)
	CityBuilder.add_box(scene, "Ground", Vector3(0, -0.25, 0), Vector3(40, 0.5, 40), Color("737b82"))
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	check(FileAccess.get_sha256("res://assets/models/characters/modular/citizen.glb") == ModularCharacter.CONTACT.MODEL_SHA256, "profiles match source GLB")
	for bare in [false, true]:
		var model := ModularCharacter.build(CharacterStyle.preset(0), bare)
		scene.add_child(model)
		var ap := ModularCharacter.animation_player(model)
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in ["idle", "walk", "run"]:
			ap.play(clip)
			var low := INF
			var high := -INF
			for i in 49:
				ap.seek(ap.current_animation_length * (i + 0.37) / 49.0, true)
				await process_frame
				await RenderingServer.frame_post_draw
				var value := sole_minimum(model, bare)
				low = minf(low, value)
				high = maxf(high, value)
				check(absf(value) <= 0.02, "sole contact %s bare=%s sample=%d y=%.4f" % [clip, bare, i, value])
			report.append("%s bare=%s support=[%.4f, %.4f] m" % [clip, bare, low, high])
			await snap("%s-%s" % ["bare" if bare else "shoes", clip], Vector3(0, 0.4, 0), 2.0)
		# Blend transitions are sampled too, not just exact source keys.
		ap.play("idle")
		ap.advance(0.0)
		for clip in ["walk", "run", "idle"]:
			ap.play(clip, 0.18)
			model.get_child(0).begin_contact_blend(0.3)
			for i in 14:
				ap.advance(1.0 / 60.0)
				await process_frame
				await RenderingServer.frame_post_draw
				check(absf(sole_minimum(model, bare)) <= 0.02, "blend contact %s bare=%s frame=%d" % [clip, bare, i])
		model.free()
	# Independent mesh geometry, not fitted_size metadata: each road wheel.
	for path in ModelLibrary.CAR_MODELS:
		var car := ModelLibrary.instance_fitted(path, 4.2, true)
		CityBuilder.fit_car_width(car)
		scene.add_child(car)
		var wheels := 0
		for mesh in car.find_children("*", "MeshInstance3D", true, false):
			if not str(mesh.name).begins_with("wheel-") or str(mesh.name) == "wheel-back":
				continue # SUV spare wheel is not a contact point.
			var low := INF
			for s in mesh.mesh.get_surface_count():
				for v in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					low = minf(low, (mesh.global_transform * v).y)
			check(absf(low) <= 0.002, path.get_file() + " " + str(mesh.name) + " support")
			wheels += 1
		check(wheels == 4, path.get_file() + " four road wheels")
		await snap(path.get_file().get_basename(), Vector3(0, 0.5, 0), 4.0)
		car.free()
	# Real spawn paths: parked bay geometry and moving cars in both axes.
	CityBuilder._add_car(scene, Vector3(10, 0, 0), 0.0)
	var parked: Node3D = get_nodes_in_group("parked_cars")[0]
	var bay: Node3D = scene.get_node("ParkingBay")
	var bay_mesh: MeshInstance3D = bay.get_child(0)
	var bay_box: AABB = bay_mesh.global_transform * bay_mesh.get_aabb()
	check(absf(parked.position.y - bay_box.end.y) < 0.002, "parked wheels on visible bay top")
	for axis in [true, false]:
		var car = load("res://scripts/traffic_car.gd").new()
		car.setup(axis, 1.0, 0.0)
		scene.add_child(car)
		check(absf(car.position.y - 0.008) < 0.002, "traffic spawn on asphalt")
		var start: Vector3 = car.position
		for i in 30:
			await physics_frame
		check(car.position.distance_to(start) > 1.0, "grounded traffic still moves")
		check(absf(car.position.y - 0.008) < 0.002, "traffic stays supported while moving")
		car.free()
	# Actual capsule on level pavement and a ramp, including stopped movement.
	CityBuilder._add_sidewalk_span(scene, Vector2(4, 14), 5.0, true)
	var actor := CharacterBase.new()
	scene.add_child(actor)
	actor.build_character(CharacterStyle.preset(1))
	actor.set_process(false)
	actor.position = Vector3(3, 0.2, 5)
	var actor_ap := actor.motion_player
	actor_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor_ap.play("walk")
	var ramp_samples := 0
	var sidewalk_samples := 0
	var ramp_low := INF
	var ramp_high := -INF
	for i in 130:
		await physics_frame
		actor.velocity = Vector3(1.2 if i < 110 else 0.0, -1, 0)
		actor.move_and_slide()
		actor_ap.advance(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if actor.position.x > 4.1 and actor.position.x < 4.7:
			ramp_samples += 1
			var gap := INF
			for mesh in actor.current_model.find_children("*", "MeshInstance3D", true, false):
				if str(mesh.name) not in ["BootL", "BootR"]: continue
				var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
				for s in baked.get_surface_count():
					for v in baked.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
						var world: Vector3 = mesh.global_transform * v
						var floor_y := 0.0 if world.x < 4.0 else lerpf(0.005, 0.12, clampf((world.x - 4.0) / 0.8, 0, 1))
						gap = minf(gap, world.y - floor_y)
			check(absf(gap) < 0.02, "ramp sole clearance %.4f" % gap)
			ramp_low = minf(ramp_low, gap)
			ramp_high = maxf(ramp_high, gap)
			check(actor.is_on_floor(), "ramp maintains physical support")
		if actor.position.x > 4.9:
			sidewalk_samples += 1
			check(absf(sole_minimum(actor.current_model, false) - 0.12) < 0.02, "feet on raised sidewalk")
	report.append("ramp clearance=[%.4f, %.4f] m" % [ramp_low, ramp_high])
	check(ramp_samples > 0 and sidewalk_samples > 0, "walk covered ramp and sidewalk")
	await snap("sidewalk-support", actor.position + Vector3(0, 0.4, 0), 2.0)
	actor.free()
	print("GROUND_CONTACT_TESTS checks=", checks, " failures=", failures.size())
	for line in report:
		print("GROUND_CONTACT ", line)
	var output := FileAccess.open(OUT + "/measurements.txt", FileAccess.WRITE)
	output.store_string("\n".join(report) + "\nchecks=%d failures=%d\n" % [checks, failures.size()])
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
