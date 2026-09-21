class_name PlacementFeedback
extends RefCounted

static func progress_ring(parent: Node3D) -> Node3D:
	var ring := Node3D.new()
	ring.name = "PlacementProgress"
	parent.add_child(ring)
	for i in 24:
		var segment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.018, 0.045)
		mesh.material = Palette.flat_material(Palette.PLAYER_RING)
		segment.mesh = mesh
		var angle := TAU * float(i) / 24.0
		segment.position = Vector3(sin(angle) * 0.73, 0.08, cos(angle) * 0.73)
		segment.rotation.y = angle
		ring.add_child(segment)
	return ring

static func update_ring(ring: Node3D, progress: float) -> void:
	for i in ring.get_child_count():
		ring.get_child(i).visible = float(i) / ring.get_child_count() <= progress

static func settle(prop: Node3D) -> void:
	# Move only the art. The authoritative collision stays grounded throughout.
	for child in prop.get_children():
		if child is Node3D and not child is CollisionShape3D and not child is Label3D:
			var final_position: Vector3 = child.position
			child.position.y += 0.18
			var tween := prop.create_tween()
			tween.tween_property(child, "position", final_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst(prop.get_parent(), prop.global_position, false)

static func burst(parent: Node3D, at: Vector3, broken: bool) -> void:
	var effect := Node3D.new()
	effect.name = "DecoyDebris" if broken else "PlacementDust"
	parent.add_child(effect)
	effect.global_position = at + Vector3(0, 0.08, 0)
	var tween := effect.create_tween().set_parallel(true)
	for i in 8:
		var particle := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * (0.09 if broken else 0.055)
		mesh.material = Palette.flat_material(Palette.PROP_CRATE if broken else Palette.SIDEWALK)
		particle.mesh = mesh
		effect.add_child(particle)
		var angle := TAU * float(i) / 8.0
		var destination := Vector3(sin(angle) * 0.5, 0.10 + (i % 3) * 0.05, cos(angle) * 0.5)
		tween.tween_property(particle, "position", destination, 0.35)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.35)
	tween.finished.connect(effect.queue_free)
