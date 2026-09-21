extends CanvasLayer

var game: Node3D
var panel: ColorRect
var paused_at := 0
var saved_mouse := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	panel = ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = Color(0.02, 0.03, 0.05, 0.86)
	panel.visible = false
	add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = "JOGO PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	for item in [["Continuar", resume], ["Voltar ao menu", leave_to_menu], ["Sair do jogo", exit_game]]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size.y = 52
		button.pressed.connect(item[1])
		box.add_child(button)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or game.phase != "playing":
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		resume()
	elif game.player.placement_mode != "":
		game.player._exit_placement()
	elif game.minimap.expanded:
		game.cancel_route_selection()
		game.cancel_remote_alarm()
	else:
		pause()

func pause() -> void:
	if get_tree().paused:
		return
	saved_mouse = Input.mouse_mode
	paused_at = Time.get_ticks_msec()
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume() -> void:
	if not get_tree().paused:
		return
	game.shift_paused_timestamps(Time.get_ticks_msec() - paused_at)
	get_tree().paused = false
	panel.hide()
	Input.mouse_mode = saved_mouse

func leave_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()
