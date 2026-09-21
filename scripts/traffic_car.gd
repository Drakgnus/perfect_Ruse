extends CharacterBody3D

# Carro que dirige por uma rua do grid e para nos semaforos. Quando parado,
# vira alvo roubavel (respeitando a linha de visao do policial). Ao voltar a
# andar, sai do grupo roubavel e some da beira do mapa (loop).

const SPEED := 7.0
const STOP_DISTANCE := 7.0     # comeca a frear a esta distancia do cruzamento
const STOP_LINE := 5.0         # onde para antes do centro do cruzamento
const LANE := 1.7              # deslocamento para a faixa da direita
const BRAKE_DIST := 4.5        # freia se um pedestre estiver a esta distancia a frente
const BRAKE_SIDE := 1.8        # largura da faixa que considera "a frente"

var game: Node3D
var travel_is_x := true        # dirige ao longo do eixo X (senao Z)
var dir_sign := 1.0            # +1 ou -1
var road_line := 0.0          # coordenada perpendicular (linha da rua)
var collision_shape: CollisionShape3D
var stopped := false
var robbable_added := false

func setup(is_x: bool, sign: float, road: float) -> void:
	travel_is_x = is_x
	dir_sign = sign
	road_line = road

func _ready() -> void:
	game = get_parent()
	add_to_group("traffic_cars")
	add_to_group("road_vehicles")
	_build_visual()
	# Orienta o carro na direcao de movimento.
	if travel_is_x:
		rotation_degrees.y = 90.0 if dir_sign > 0 else -90.0
	else:
		rotation_degrees.y = 0.0 if dir_sign > 0 else 180.0
	# Faixa da direita em relacao a direcao.
	var lane_off := LANE * dir_sign * (1.0 if travel_is_x else -1.0)
	if travel_is_x:
		position = Vector3(position.x, 0.15, road_line + lane_off)
	else:
		position = Vector3(road_line + lane_off, 0.15, position.z)

	# Resolve random spawn conflicts before the first physics tick.
	for slot in [-CityBuilder.MAP_HALF + 6.0, -CityBuilder.ROAD_SPACING * 0.5, CityBuilder.ROAD_SPACING * 0.5, CityBuilder.MAP_HALF - 6.0, -CityBuilder.ROAD_SPACING * 1.5, CityBuilder.ROAD_SPACING * 1.5, -CityBuilder.ROAD_SPACING * 1.25, CityBuilder.ROAD_SPACING * 1.25]:
		var candidate := global_position
		if travel_is_x:
			candidate.x = slot
		else:
			candidate.z = slot
		if _vehicles_clear(candidate):
			global_position = candidate
			break

func _build_visual() -> void:
	var size := Vector3(2.0, 1.2, 4.2)
	if ModelLibrary.has_cars():
		var model := ModelLibrary.instance_fitted(ModelLibrary.random_car_model(), 4.2, true)
		if model != null:
			add_child(model)
			size = CityBuilder.fit_car_width(model)
	if get_child_count() == 0:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.9, 1.1, 4.0)
		mesh.material = Palette.flat_material(Palette.random_civilian_color())
		mesh_instance.mesh = mesh
		mesh_instance.position.y = 0.7
		add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(1.6, size.x), maxf(1.0, size.y), maxf(3.0, size.z))
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
	collision_shape = collision
	set_meta("kind", "car")
	set_meta("label", "CARRO")
	set_meta("value", 200)
	set_meta("channel_time", 3.0)
	set_meta("cooldown", 25.0)
	set_meta("next_rob_at_ms", 0)

# World-space box includes the actual imported car dimensions and yaw.
func footprint(at: Vector3) -> AABB:
	var size: Vector3 = collision_shape.shape.size
	return Transform3D(global_basis, at) * (collision_shape.transform * AABB(-size * 0.5, size))

func _vehicles_clear(at: Vector3) -> bool:
	var box := footprint(at).grow(0.25)
	for other in get_tree().get_nodes_in_group("road_vehicles"):
		if other == self:
			continue
		for child in other.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var size: Vector3 = child.shape.size
				var other_box: AABB = child.global_transform * AABB(-size * 0.5, size)
				if box.intersects(other_box):
					return false
	return true

func _physics_process(delta: float) -> void:
	if game.phase != "playing":
		return
	var coord := global_position.x if travel_is_x else global_position.z
	var travel_dir := Vector3(dir_sign, 0, 0) if travel_is_x else Vector3(0, 0, dir_sign)
	var limit := CityBuilder.MAP_HALF - CityBuilder.CAR_LENGTH * 0.5 - 0.3
	if coord * dir_sign >= limit - 0.01:
		var destination := global_position
		if travel_is_x:
			destination.x = -dir_sign * limit
		else:
			destination.z = -dir_sign * limit
		# Never wrap into a car waiting at the opposite edge.
		if _vehicles_clear(destination) and _spawn_space_clear(destination):
			global_position = destination
			_set_stopped(false)
		else:
			_set_stopped(true)
		return
	var step := minf(SPEED * delta, limit - coord * dir_sign)
	var dist_to_int := (_next_intersection(coord) - coord) * dir_sign
	# Once past the stop line, clear the junction instead of reversing on red.
	if not game.is_axis_green(travel_is_x) and dist_to_int >= STOP_LINE - 0.01 and dist_to_int < STOP_DISTANCE:
		step = minf(step, maxf(0.0, dist_to_int - STOP_LINE))
	if step <= 0.001 or _pedestrian_ahead() or not _vehicles_clear(global_position + travel_dir * (step + 0.3)):
		_set_stopped(true)
		return
	# Use physics movement: position assignment used to pass through all bodies.
	if test_move(global_transform, travel_dir * (step + 0.15)):
		_set_stopped(true)
		return
	var collision := move_and_collide(travel_dir * step)
	_set_stopped(collision != null)

func _spawn_space_clear(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(global_basis, at) * collision_shape.transform
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _pedestrian_ahead() -> bool:
	var travel_dir := Vector3(dir_sign, 0, 0) if travel_is_x else Vector3(0, 0, dir_sign)
	for group in ["civilians", "thieves", "police"]:
		for c in get_tree().get_nodes_in_group(group):
			var to: Vector3 = c.global_position - global_position
			to.y = 0.0
			var along := to.dot(travel_dir)          # distancia a frente
			if along <= 0.5 or along > BRAKE_DIST:
				continue
			var side := (to - travel_dir * along).length()   # desvio lateral
			if side < BRAKE_SIDE:
				return true
	return false

func _next_intersection(coord: float) -> float:
	var best := INF
	var best_val := coord + dir_sign * 1000.0
	for r in CityBuilder.ROADS:
		var ahead: float = (float(r) - coord) * dir_sign
		if ahead > 0.1 and ahead < best:
			best = ahead
			best_val = float(r)
	return best_val

func _set_stopped(value: bool) -> void:
	if value == stopped:
		return
	stopped = value
	if stopped and not robbable_added:
		add_to_group("robbable")
		robbable_added = true
	elif not stopped and robbable_added:
		remove_from_group("robbable")
		robbable_added = false
