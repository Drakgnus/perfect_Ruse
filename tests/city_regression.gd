extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 12:
			push_error(label)

func _initialize() -> void:
	run.call_deferred()

func body_box(body: Node3D) -> AABB:
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size: Vector3 = child.shape.size
			return child.global_transform * AABB(-size * 0.5, size)
	return AABB()

func audit_vehicles() -> void:
	var cars := get_nodes_in_group("road_vehicles")
	for i in cars.size():
		var box := body_box(cars[i])
		for j in range(i + 1, cars.size()):
			check(not box.grow(-0.02).intersects(body_box(cars[j])), "car overlap: %s / %s" % [cars[i].name, cars[j].name])
		if cars[i].is_in_group("traffic_cars"):
			var road: float = cars[i].road_line
			var low := box.position.z if cars[i].travel_is_x else box.position.x
			var high := box.end.z if cars[i].travel_is_x else box.end.x
			check(low >= road - CityBuilder.ROAD_HALF - 0.01 and high <= road + CityBuilder.ROAD_HALF + 0.01, "whole moving car stays on road")
		for building in get_nodes_in_group("city_buildings"):
			for shape in building.find_children("*", "CollisionShape3D", true, false):
				if shape.shape is BoxShape3D:
					var size: Vector3 = shape.shape.size
					var solid: AABB = shape.global_transform * AABB(-size * 0.5, size)
					check(not box.grow(-0.02).intersects(solid), "car/building overlap: %s / %s" % [cars[i].name, building.name])

func run() -> void:
	for world in 3:
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_process(false)
		for child in game.get_children():
			if child is CharacterBase:
				child.set_physics_process(false)
				child.position = Vector3(43, 0, 43)
		check(get_nodes_in_group("road_vehicles").size() == 24 + game.TRAFFIC_COUNT, "all parked and moving cars audited")
		for building in get_nodes_in_group("city_buildings"):
			var visual := ModelLibrary.combined_aabb(building, building.global_transform)
			for road in CityBuilder.ROADS:
				check(visual.end.x <= road - CityBuilder.ROAD_HALF or visual.position.x >= road + CityBuilder.ROAD_HALF, "building visual crosses vertical road: " + building.name)
				check(visual.end.z <= road - CityBuilder.ROAD_HALF or visual.position.z >= road + CityBuilder.ROAD_HALF, "building visual crosses horizontal road: " + building.name)
		await physics_frame
		# Walkers fit around buildings and parked cars along every graph edge.
		var graph: AStar3D = game.routes.graph
		for id in graph.get_point_ids():
			for adjacent in graph.get_point_connections(id):
				if adjacent < id:
					continue
				var a := graph.get_point_position(id)
				var b := graph.get_point_position(adjacent)
				for step in 12:
					var point := a.lerp(b, step / 11.0)
					var query := PhysicsShapeQueryParameters3D.new()
					var shape := SphereShape3D.new()
					shape.radius = 0.4
					query.shape = shape
					query.transform.origin = point + Vector3(0, 0.8, 0)
					var exclude: Array[RID] = []
					for car in get_nodes_in_group("traffic_cars"):
						exclude.append(car.get_rid())
					for child in game.get_children():
						if child is CharacterBase:
							exclude.append(child.get_rid())
					query.exclude = exclude
					var hits: Array = game.get_world_3d().direct_space_state.intersect_shape(query, 1)
					check(hits.is_empty(), "blocked pedestrian edge at %s: %s" % [point, hits[0]["collider"].name if not hits.is_empty() else "clear"])
		var initial := {}
		for car in get_nodes_in_group("traffic_cars"):
			initial[car] = car.position
		audit_vehicles()
		for frame in 660:
			await physics_frame
			game._tick_traffic_lights(1.0 / 60.0)
			if frame % 30 == 0:
				audit_vehicles()
		var moved := 0
		for car in initial:
			if car.position.distance_to(initial[car]) > 2.0:
				moved += 1
		check(moved >= 6, "traffic must move, not pass by freezing every vehicle: " + str(moved))
		game.queue_free()
		await process_frame
		await process_frame
	print("CITY_TESTS checks=%d failures=%d worlds=3" % [checks, failures])
	quit(1 if failures else 0)
