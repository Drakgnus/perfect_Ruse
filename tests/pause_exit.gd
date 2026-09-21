extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.pause_menu.pause()
	for button in game.pause_menu.panel.find_children("*", "Button", true, false):
		if button.text == "Sair do jogo":
			print("PAUSE_EXIT click")
			button.pressed.emit()
	await create_timer(0.5, true).timeout
	push_error("Exit button did not close the game")
	quit(1)
