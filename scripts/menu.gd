extends Control

# Menu inicial construido por codigo (mesmo padrao da HUD). Explica o conceito
# e os controles antes de iniciar a partida.

const GAME_SCENE := "res://scenes/main.tscn"

func _ready() -> void:
	if "--shot-menu" not in OS.get_cmdline_user_args() and "--shot" in OS.get_cmdline_user_args():
		# Dev: pula direto pro jogo para capturar screenshots de gameplay.
		call_deferred("_on_play")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#1a2430")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -430
	center.offset_right = 430
	center.offset_top = -260
	center.offset_bottom = 260
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	var title := Label.new()
	title.text = "PERFECT RUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#f5c542"))
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Ladroes x Policiais — deducao, camuflagem e disfarce."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("#9ad0ff"))
	center.add_child(subtitle)

	var concept := Label.new()
	concept.text = "Roube alvos, esconda o dinheiro disfarçado como objeto do cenario e\ndespiste a policia com iscas. Se for preso, voce vira policial. O time\ndos ladroes vence ao atingir R$ 1.500; a policia vence ao converter todos."
	concept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	concept.add_theme_font_size_override("font_size", 16)
	concept.add_theme_color_override("font_color", Color("#c6cfd6"))
	center.add_child(concept)

	var controls := Label.new()
	controls.text = "WASD andar  •  Shift correr  •  E roubar/resgatar  •  C copiar molde  •  Q esconder $  •  T isca\nF copiar roupa  •  R escolher destino  •  G habilidade  •  M mapa  •  Esc pausar / sair"
	controls.text += "\nT + roda: girar isca | Shift + roda: trocar face | V: mover isca na mira"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color("#8b96a0"))
	center.add_child(controls)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	center.add_child(spacer)

	var play := Button.new()
	play.text = "JOGAR"
	play.custom_minimum_size = Vector2(260, 56)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 26)
	play.pressed.connect(_on_play)
	center.add_child(play)

	var wardrobe := Button.new()
	wardrobe.text = "PERSONAGEM E ACESSORIOS"
	wardrobe.custom_minimum_size = Vector2(360, 46)
	wardrobe.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wardrobe.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/wardrobe.tscn"))
	center.add_child(wardrobe)

	var molds := Button.new()
	molds.text = "MOLDES DE BOLSO"
	molds.custom_minimum_size = Vector2(360, 46)
	molds.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	molds.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/mold_kit.tscn"))
	center.add_child(molds)

	var quit := Button.new()
	quit.text = "SAIR"
	quit.custom_minimum_size = Vector2(260, 46)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.add_theme_font_size_override("font_size", 20)
	quit.pressed.connect(_on_quit)
	center.add_child(quit)

	play.grab_focus()
	if "--shot-menu" in OS.get_cmdline_user_args():
		_capture_menu_shot.call_deferred()

func _capture_menu_shot() -> void:
	await get_tree().create_timer(0.8).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://shot_menu.png")
	print("SHOT_SAVED:", ProjectSettings.globalize_path("user://shot_menu.png"))
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		_on_play()

func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_quit() -> void:
	get_tree().quit()
