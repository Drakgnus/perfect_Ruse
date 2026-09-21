extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(1.5).timeout
	var player: CharacterBase = game.player
	# Place two citizens in view for repeatable scale/silhouette evidence.
	var citizens := get_nodes_in_group("civilians")
	for i in 3:
		citizens[i].position = Vector3(-1.5 + i * 1.5, 0.2, -2.5)
		citizens[i].home = citizens[i].position
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://gameplay-characters.png")
	Input.action_press("move_forward")
	await create_timer(0.7).timeout
	Input.action_release("move_forward")
	var samples: Array[float] = []
	for i in 180:
		await process_frame
		samples.append(root.get_process_delta_time())
	var sum := 0.0
	for value in samples:
		sum += value
	print("VISUAL_SMOKE frames=", samples.size(), " mean_fps=", snappedf(samples.size()/sum, 0.1), " civilians=", get_nodes_in_group("civilians").size())
	game.queue_free()
	await process_frame
	await process_frame
	quit()
