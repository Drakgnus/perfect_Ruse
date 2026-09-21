extends Node3D

# Crossfading grounded clips does not necessarily ground the blended pose.
# During transitions or on ramps, evaluate the two rigid foot hulls on the CPU.
# Level playback uses precomputed curves; ramp support uses its physical plane.
static var hull_cache: Dictionary = {}
var feet: Array[Dictionary] = []
var skeleton: Skeleton3D
var correction_left := 0.0
var actor: CharacterBody3D
var slope_active := false
var support_plane := Plane(Vector3.UP, 0.0)

func _ready() -> void:
	skeleton = find_child("Skeleton3D", true, false)
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CharacterBody3D:
			actor = ancestor
			break
		ancestor = ancestor.get_parent()
	set_physics_process(actor != null)
	for name in ["BootL", "BootR", "FootL", "FootR"]:
		var mesh: MeshInstance3D = find_child(name, true, false)
		if mesh == null or not mesh.visible:
			continue
		if not hull_cache.has(name):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var bind_index: int = arrays[Mesh.ARRAY_BONES][0]
			var bone_name := mesh.skin.get_bind_name(bind_index)
			var bone := skeleton.find_bone(bone_name) if bone_name != &"" else mesh.skin.get_bind_bone(bind_index)
			var shape := mesh.mesh.create_convex_shape(true, true)
			var points := PackedVector3Array()
			for vertex in shape.points:
				points.append(mesh.skin.get_bind_pose(bind_index) * vertex)
			hull_cache[name] = {"bone": bone, "points": points}
		feet.append(hull_cache[name])
	skeleton.skeleton_updated.connect(_correct_blended_contact)
	set_process(false)

func begin_contact_blend(seconds: float) -> void:
	correction_left = seconds
	set_process(true)

func _process(delta: float) -> void:
	correction_left = maxf(0.0, correction_left - delta)
	if correction_left <= 0.0:
		set_process(false)

func _physics_process(_delta: float) -> void:
	slope_active = false
	if not is_instance_valid(actor) or not actor.is_on_floor() or actor.get_floor_normal().y > 0.9999:
		return
	var at := actor.global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at - Vector3.UP * 0.4)
	query.exclude = [actor.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["normal"].y > 0.7:
		support_plane = Plane(hit["normal"], hit["position"])
		slope_active = true

func _correct_blended_contact() -> void:
	if not is_inside_tree() or not is_instance_valid(skeleton) or not skeleton.is_inside_tree():
		return
	if (correction_left <= 0.0 and not slope_active) or feet.is_empty():
		return
	var low := INF
	var plane := support_plane if slope_active else Plane(Vector3.UP, get_parent().global_position.y)
	for foot in feet:
		var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(foot["bone"])
		for vertex in foot["points"]:
			low = minf(low, plane.distance_to(pose * vertex))
	# Keep the parent's placement/knockout transform independent of locomotion.
	if absf(global_basis.y.dot(Vector3.UP)) > 0.99:
		global_position.y += (0.002 - low) / plane.normal.y
