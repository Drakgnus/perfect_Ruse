class_name PropPlacement
extends RefCounted

# Align a face to the hit surface. Project the visual bounds so rotation never
# leaves the object floating above (or buried behind) the support plane.
static func on_surface(point: Vector3, normal: Vector3, bounds: AABB, spin: float, face: int) -> Transform3D:
	var up := normal.normalized()
	var tangent := Vector3.RIGHT
	if absf(up.dot(tangent)) > 0.95:
		tangent = Vector3.FORWARD
	tangent = (tangent - up * tangent.dot(up)).normalized()
	var aligned := Basis(tangent, up, tangent.cross(up))
	var orientation := Basis(up, spin) * aligned * Basis(Vector3.RIGHT, face * PI / 2.0)
	var minimum := INF
	for i in 8:
		minimum = minf(minimum, up.dot(orientation * bounds.get_endpoint(i)))
	return Transform3D(orientation, point - up * minimum + up * 0.005)

static func valid_basis(value: Basis) -> bool:
	return value.is_finite() and value.is_equal_approx(value.orthonormalized()) and is_equal_approx(value.determinant(), 1.0)
