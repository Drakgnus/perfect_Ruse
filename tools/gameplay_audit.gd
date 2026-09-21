extends SceneTree

# Diagnostic observations, not acceptance tests for the desired game design.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.set_process(false)
	for child in game.get_children():
		child.set_process(false)
		child.set_physics_process(false)
	var thieves := get_nodes_in_group("thieves")
	for thief in thieves:
		thief.carried_money = 250
		thief.suspicion = 0
	game._tick_suspicion(10.0)
	var officer: CharacterBase = get_nodes_in_group("police")[0]
	officer.position = Vector3.ZERO
	officer.face_direction(Vector3(0, 0, 1))
	var observations := {
		"thieves": thieves.size(),
		"goal": game.MONEY_GOAL,
		"money_with_250_each": game.team_money(),
		"hidden_money": game.hidden_money(),
		"player_suspicion_after_10_seconds": game.player.suspicion,
		"visual_front_dot_target": officer.global_basis.z.dot(Vector3(0, 0, 1)),
		"vision_front_dot_target": (-officer.global_basis.z).dot(Vector3(0, 0, 1)),
	}
	game._check_thieves_victory()
	observations["phase_with_only_carried_money"] = game.phase
	game.phase = "playing"
	for child in get_nodes_in_group("friskable"):
		child.position = Vector3(90, 0, 90)
	var ordinary := CityBuilder.create_prop("crate")
	game.add_child(ordinary)
	ordinary.position = Vector3(0, 0, 1)
	observations["ordinary_prop_inspectable"] = not game.find_police_interactable(officer).is_empty()
	game.placed_objects.append({"node": ordinary, "amount": 0, "owner": game.player, "created_ms": Time.get_ticks_msec(), "claimed": false})
	observations["same_prop_registered_as_decoy_inspectable"] = not game.find_police_interactable(officer).is_empty()
	game.raise_alert(Vector3.ZERO)
	observations["ai_selects_registered_prop"] = game.claim_suspect_stash(officer) == ordinary
	game.player.velocity = Vector3.ZERO
	game.player.carried_money = 1
	game.player.suspicion = 0
	observations["ai_carrying_clue_for_one_hidden_real"] = officer._is_clearly_fleeing_or_carrying(game.player)
	print("GAMEPLAY_AUDIT ", JSON.stringify(observations))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/validation/gameplay-audit"))
	var file := FileAccess.open("res://docs/validation/gameplay-audit/observations.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(observations, "\t") + "\n")
	file.close()
	await create_timer(1.5).timeout
	game.queue_free()
	await process_frame
	await process_frame
	quit()
