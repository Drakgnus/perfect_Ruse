class_name CityRoutes
extends RefCounted

const WALK_OFFSET := CityBuilder.SIDEWALK_MID + 0.75
var graph := AStar3D.new()
var axes: Array[float] = []
var destinations: Array[int] = []

func _init() -> void:
	axes.append(-CityBuilder.MAP_HALF + 2.5)
	for road in CityBuilder.ROADS:
		axes.append(road - WALK_OFFSET)
		axes.append(road + WALK_OFFSET)
	axes.append(CityBuilder.MAP_HALF - 2.5)
	var count := axes.size()
	var cells := {}
	for x in count:
		for z in count:
			if x in [0, count - 1] and z in [0, count - 1]:
				continue
			var id := graph.get_point_count()
			cells[Vector2i(x, z)] = id
			graph.add_point(id, Vector3(axes[x], CityBuilder.SIDEWALK_H + 0.05, axes[z]))
	for x in count:
		for z in count:
			if not cells.has(Vector2i(x, z)):
				continue
			var id: int = cells[Vector2i(x, z)]
			if z > 0 and z < count - 1 and cells.has(Vector2i(x + 1, z)):
				graph.connect_points(id, cells[Vector2i(x + 1, z)])
			if x > 0 and x < count - 1 and cells.has(Vector2i(x, z + 1)):
				graph.connect_points(id, cells[Vector2i(x, z + 1)])

func nearest(point: Vector3) -> Vector3:
	return graph.get_point_position(graph.get_closest_point(point))

func path(from: Vector3, destination: Vector3) -> PackedVector3Array:
	return graph.get_point_path(graph.get_closest_point(from), graph.get_closest_point(destination))

func random_destination(from: Vector3) -> Vector3:
	var result := nearest(from)
	for attempt in 12:
		var id: int = destinations.pick_random() if not destinations.is_empty() else randi_range(0, graph.get_point_count() - 1)
		result = graph.get_point_position(id)
		if from.distance_to(result) > 15.0:
			break
	return result

func add_destination(point: Vector3) -> void:
	var best := INF
	var a_id := 0
	var b_id := 0
	var projected := Vector3.ZERO
	for id in graph.get_point_ids():
		for neighbor in graph.get_point_connections(id):
			if neighbor < id:
				continue
			var a := graph.get_point_position(id)
			var b := graph.get_point_position(neighbor)
			var candidate := a + (b - a) * clampf((point - a).dot(b - a) / a.distance_squared_to(b), 0.0, 1.0)
			if candidate.distance_squared_to(point) < best:
				best = candidate.distance_squared_to(point)
				projected = candidate
				a_id = id
				b_id = neighbor
	var id := graph.get_point_count()
	graph.add_point(id, projected)
	graph.connect_points(id, a_id)
	graph.connect_points(id, b_id)
	destinations.append(id)

# Predict pedestrians' crossing conflict with vehicles. Sidewalk travel is free.
static func car_approaching(walker: Node3D, waypoint: Vector3) -> bool:
	var direction := walker.global_position.direction_to(waypoint)
	for car in walker.get_tree().get_nodes_in_group("traffic_cars"):
		if car.stopped:
			continue
		var relative: Vector3 = car.global_position - walker.global_position
		relative.y = 0
		if relative.length() < 4.5 and relative.dot(direction) > 0.0:
			return true
	return false
