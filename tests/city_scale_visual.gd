extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	seed(2026)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(1.0).timeout
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.fov = 65
	camera.position = Vector3(-3, 7, -4)
	camera.look_at(Vector3(-28, 4, -27))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/city-scale-street.png")
	var shop: Node3D
	for target in get_nodes_in_group("robbable"):
		if target.get_meta("kind", "") == "store":
			shop = target
			break
	var forward: Vector3 = shop.global_basis.z
	game.player.set_physics_process(false)
	game.player.global_position = shop.global_position + forward * 1.0
	camera.global_position = shop.global_position + forward * 13 + Vector3(5, 5, 0)
	camera.look_at(shop.global_position + Vector3(0, 2.3, 0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/city-scale-shop.png")
	print("CITY_SCALE_VISUAL PASS")
	quit()
