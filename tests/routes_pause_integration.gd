extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	for child in game.get_children():
		if child is CharacterBase or child.is_in_group("traffic_cars"):
			child.set_physics_process(false)
	check(game.routes.destinations.size() == 12, "shops and ATMs give twelve destinations")
	var starts := {}
	for npc in get_nodes_in_group("civilians"):
		starts[npc.position] = true
	check(starts.size() == game.CIVILIAN_COUNT, "civilians start at distinct sidewalk locations")
	var player = game.player
	player.position = Vector3(-CityRoutes.WALK_OFFSET, 0.2, -CityRoutes.WALK_OFFSET)
	game.begin_route_selection()
	check(game.minimap.expanded and game.route_selecting and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "R selection opens clickable map")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.minimap._world_to_map(CityRoutes.WALK_OFFSET, -CityRoutes.WALK_OFFSET)
	game.minimap._gui_input(click)
	check(player.blending and player.city_route.size() >= 2, "map click creates route")
	check(not game.minimap.expanded and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "map closes and camera captures")
	var body_yaw: float = player.rotation.y
	var orbit := InputEventMouseMotion.new()
	orbit.relative = Vector2(120, 20)
	player._unhandled_input(orbit)
	check(is_equal_approx(player.rotation.y, body_yaw) and absf(player.camera_pivot.rotation.y) > 0.1, "mouse orbits independently of body")
	var pivot_yaw: float = player.camera_pivot.rotation.y
	player._follow_copied_route(0.016)
	check(is_equal_approx(player.camera_pivot.rotation.y, pivot_yaw), "route movement does not reset camera")
	player._stop_blend()
	check(not player.blending and is_zero_approx(player.camera_pivot.rotation.y), "route cancel restores manual controls")
	game.begin_route_selection()
	game.cancel_route_selection()
	check(not game.route_selecting and not game.minimap.expanded, "cancel map works")
	# Exercise the actual scene pause and clock compensation.
	var shop = get_nodes_in_group("robbable")[0]
	shop.set_meta("next_rob_at_ms", Time.get_ticks_msec() + 10000)
	var deadline: int = shop.get_meta("next_rob_at_ms")
	game.player.mark_checked(10.0)
	var checked: int = game.player.checked_until_ms
	var light: float = game.light_timer
	game.pause_menu.pause()
	check(paused and game.pause_menu.panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause freezes tree and shows menu")
	await create_timer(0.12, true).timeout
	check(is_equal_approx(game.light_timer, light), "world timer remains stopped")
	game.pause_menu.resume()
	check(not paused and not game.pause_menu.panel.visible, "continue unpauses")
	check(int(shop.get_meta("next_rob_at_ms")) > deadline and player.checked_until_ms > checked, "wall-clock deadlines shifted by pause")
	var labels: Array[String] = []
	for button in game.pause_menu.panel.find_children("*", "Button", true, false):
		labels.append(button.text)
	check(labels == ["Continuar", "Voltar ao menu", "Sair do jogo"], "all pause actions clickable")
	# A short destination completes rather than oscillating forever.
	for child in game.get_children():
		if child is CharacterBase and child != player:
			child.position = Vector3(43, 0, 43)
	var npc = get_nodes_in_group("civilians")[0]
	npc.position = Vector3(-12, 0.2, -CityRoutes.WALK_OFFSET)
	npc.route = PackedVector3Array([Vector3(-10.5, 0.2, -CityRoutes.WALK_OFFSET)])
	npc.route_index = 0
	npc.visit_left = 0.0
	npc.set_physics_process(true)
	for frame in 120:
		await physics_frame
	check(npc.visits > 0, "NPC arrives and pauses at destination")
	npc.set_physics_process(false)
	npc.position = Vector3(60, 0.2, 60)
	# End-to-end crossing: leave one raised sidewalk, cross, climb the other.
	player.position = Vector3(-CityRoutes.WALK_OFFSET, 0.2, -CityRoutes.WALK_OFFSET)
	var end := Vector3(CityRoutes.WALK_OFFSET, 0.2, -CityRoutes.WALK_OFFSET)
	player.start_city_route(PackedVector3Array([player.position, end]))
	player.set_physics_process(true)
	for frame in 760:
		await physics_frame
	check(not player.blending and player.position.distance_to(end) < 0.6, "automatic route crosses street and climbs sidewalk ramps")
	player.set_physics_process(false)
	game.pause_menu.pause()
	game.pause_menu.leave_to_menu()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == "res://scenes/menu.tscn", "menu button changes scene and clears pause")
	print("ROUTES_PAUSE_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
