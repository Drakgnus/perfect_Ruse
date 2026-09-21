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
	var bounds := AABB(Vector3(-0.5, 0, -0.4), Vector3(1, 1.2, 0.8))
	for normal in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		for face in 4:
			for spin in [0.0, 0.25, 1.5]:
				var pose := PropPlacement.on_surface(Vector3.ZERO, normal, bounds, spin, face)
				var minimum := INF
				for i in 8:
					minimum = minf(minimum, normal.dot(pose * bounds.get_endpoint(i)))
				check(absf(minimum - 0.005) < 0.001, "surface contact")
				check(PropPlacement.valid_basis(pose.basis), "proper rotation")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	for child in game.get_children():
		child.set_physics_process(false)
		if child is CharacterBase or child.is_in_group("traffic_cars"):
			child.position = Vector3(43, 0, 43)
	var player = game.player
	player.position = Vector3(0, 0, -1)
	player.copied_prop_type = "crate"
	player.carried_money = 450
	CityBuilder.add_box(game, "TestWall", Vector3(0, 2, -5), Vector3(4, 4, 0.4), Palette.BUILDING_B)
	await physics_frame
	await physics_frame
	check(game.is_placement_position_valid(Vector3(12, 3, 12)), "lots and height allowed")
	check(not game.is_placement_position_valid(Vector3(INF, 0, 0)), "nonfinite rejected")
	# Fora do dominio: derivado do mapa, nunca um numero fixo. Com a cidade de
	# 20/09 (ROAD_SPACING 64) o antigo 90 passou a ser dentro e o teste quebrou.
	check(not game.hide_money_at(player, Vector3(CityBuilder.MAP_HALF + 10.0, 0, 0)), "world bounds retained")
	check(player.carried_money == 450, "invalid placement retains money")
	player._update_camera_collision()
	player._toggle_placement("decoy")
	player._update_ghost()
	check(player.ghost_valid, "camera ray picks wall")
	check(player.ghost_basis.y.dot(Vector3.BACK) > 0.99, "base faces wall")
	var before: Basis = player.ghost_basis
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	player._unhandled_input(wheel)
	player._update_ghost()
	check(not player.ghost_basis.is_equal_approx(before), "wheel rotates")
	wheel.shift_pressed = true
	player._unhandled_input(wheel)
	player._update_ghost()
	check(player.placement_face == 1, "shift wheel changes face")
	var pose: Transform3D = player.ghost.transform
	player._confirm_placement()
	player._physics_process(0.01)
	check(player.placement_active, "click starts placement")
	player._tick_placement(0.4)
	check(game.placed_objects.is_empty(), "delay before commit")
	player._tick_placement(0.4)
	check(game.placed_objects.size() == 1, "wall decoy committed")
	if game.placed_objects.is_empty():
		quit(1)
		return
	var decoy = game.placed_objects[0]["node"]
	check(decoy.global_transform.is_equal_approx(pose), "preview preserved")
	game.place_decoy_at(player, pose.origin, pose.basis)
	check(game.placed_objects.size() == 2, "full overlap allowed")
	check(game.hide_money_at(player, pose.origin, pose.basis), "mounted stash supported")
	check(player.carried_money == 0, "money debited once")
	var stranger = get_nodes_in_group("thieves")[1]
	check(not game.move_decoy(stranger, decoy, pose), "cannot move other's decoy")
	var moved := pose
	moved.origin.x += 1.0
	check(game.move_decoy(player, decoy, moved), "owner can move")
	check(game._decoy_count(player) == 2, "move preserves quota")
	await physics_frame
	player.camera.look_at(decoy.global_transform * Vector3(0, 0.55, 0), Vector3.UP)
	player._start_decoy_edit()
	check(player.placement_mode == "move_decoy", "aim selects decoy")
	player._exit_placement()
	check(decoy.global_transform.is_equal_approx(moved), "cancel edit preserves original")
	player.carried_money = 123
	player._toggle_placement("stash")
	player._begin_placement()
	player.frozen = true
	player._tick_placement(1.0)
	check(player.carried_money == 123 and not player.placement_active, "arrest cancels without debit")
	player.frozen = false
	var officer = get_nodes_in_group("police")[0]
	var money: int = game.recovered_money
	game.recover_stash(officer, decoy)
	check(game._decoy_count(player) == 1 and game.recovered_money == money, "police destroys bait")
	game.recover_stash(officer, game.placed_objects[-1]["node"])
	check(game.recovered_money == money + 450, "mounted stash recoverable")
	game._reveal_police(0.01)
	game._reveal_police(0.03)
	await create_timer(0.2).timeout
	await process_frame
	check(officer.get_node_or_null("RevealMarker") == null, "repeated reveal safe")
	await create_timer(1.0).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("PLACEMENT_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
