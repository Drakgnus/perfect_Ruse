extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(1.5).timeout
	await capture("res://docs/urban-city.png")
	game.set_process(false)
	for child in game.get_children():
		child.set_physics_process(false)
	var player = game.player
	# 20/09: com o quarteirao em ANEL, a face -Z do predio mais proximo do centro
	# pode dar para o patio interno. Em vez de assumir uma fachada, procura a
	# primeira que aceita a isca — assim o teste nao depende do layout.
	var candidates: Array = []
	for building in get_nodes_in_group("city_buildings"):
		if building is StaticBody3D:
			candidates.append(building)
	candidates.sort_custom(func(a, b): return a.global_position.length() < b.global_position.length())
	player.copied_prop_type = "crate"
	player.camera_pivot.rotation = Vector3.ZERO
	player.rotation.y = PI
	for building in candidates:
		var bounds := ModelLibrary.combined_aabb(building, building.global_transform)
		player.position = Vector3(bounds.get_center().x, 0.2, bounds.position.z - 3.0)
		await physics_frame
		player._update_camera_collision()
		if player.placement_mode != "decoy":
			player._toggle_placement("decoy")
		player.placement_spin = deg_to_rad(30)
		player.placement_face = 1
		player._update_ghost()
		if player.ghost_valid:
			break
	if not player.ghost_valid:
		push_error("Visual wall placement has no valid surface")
	else:
		player._begin_placement()
		player._tick_placement(0.4)
		game._update_hud()
		await capture("res://docs/urban-wall-preview.png")
		player._tick_placement(0.41)
		await create_timer(0.3).timeout
		game._update_hud()
		await capture("res://docs/urban-wall-placed.png")
	game.begin_route_selection()
	game.choose_route_destination(Vector3(-36, 0, 36))
	game._set_map_expanded(true)
	await capture("res://docs/urban-route-map.png")
	game.cancel_route_selection()
	game.pause_menu.pause()
	await capture("res://docs/urban-pause.png")
	game.pause_menu.resume()
	for node in game.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	print("URBAN_VISUAL_SMOKE captures=5")
	quit()
