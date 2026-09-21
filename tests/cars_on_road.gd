extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var checked := 0
	var failures := 0
	for pass_i in 6:
		for frame in 40:
			await physics_frame
		for car in get_nodes_in_group("road_vehicles"):
			checked += 1
			var road := INF
			var horizontal := absf(sin(car.rotation.y)) > 0.5
			var lateral: float = car.global_position.z if horizontal else car.global_position.x
			for center in CityBuilder.ROADS:
				road = minf(road, absf(lateral - center))
			var valid: bool = is_equal_approx(road, CityBuilder.PARK_LANE_OFFSET) if car.is_in_group("parked_cars") else road + CityBuilder.CAR_WIDTH * 0.5 <= CityBuilder.ROAD_HALF
			if not valid:
				failures += 1
				push_error("Car outside lane/bay: " + str(car.global_position))
	for node in game.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	print("CARS_ON_ROAD checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)
