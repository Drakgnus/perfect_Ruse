extends Control

var outfit: Dictionary
var preview_root: Node3D
var visual: Node3D
var anim: AnimationPlayer
var choices: VBoxContainer
var preview_police := false
var motion := "idle"
var status: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	outfit = CharacterStyle.player_outfit()
	var bg := ColorRect.new()
	bg.color = Color("#172330")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 26)
	margin.add_child(layout)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(left)
	var title := Label.new()
	title.text = "SEU PERSONAGEM"
	title.add_theme_font_size_override("font_size", 30)
	left.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Uma identidade para se misturar na cidade."
	left.add_child(subtitle)
	var view_container := SubViewportContainer.new()
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container.stretch = true
	left.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view_container.add_child(viewport)
	preview_root = Node3D.new()
	viewport.add_child(preview_root)
	var camera := Camera3D.new()
	camera.position = Vector3(2.1, 1.5, 4.4)
	preview_root.add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.3
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.45
	preview_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.1
	preview_root.add_child(light)
	var ground := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.6
	cylinder.height = 0.04
	ground.mesh = cylinder
	ground.position.y = -0.02
	ground.material_override = Palette.flat_material(Palette.SIGN)
	preview_root.add_child(ground)
	var motion_row := HBoxContainer.new()
	left.add_child(motion_row)
	for item in [["Parado", "idle"], ["Andar", "walk"], ["Correr", "run"]]:
		var button := Button.new()
		button.text = item[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): motion = item[1]; _refresh())
		motion_row.add_child(button)
	var police_button := CheckButton.new()
	police_button.text = "Visualizar uniforme policial"
	police_button.toggled.connect(func(on: bool): preview_police = on; _refresh())
	left.add_child(police_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 360
	layout.add_child(scroll)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 8)
	scroll.add_child(choices)
	_controls()
	_refresh()
	if "--capture-wardrobe" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _capture() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://wardrobe-preview.png")
	preview_police = true
	_refresh()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://police-preview.png")
	get_tree().quit()

func _controls() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var presets := OptionButton.new()
	for name in CharacterStyle.PRESET_NAMES:
		presets.add_item(name)
	presets.item_selected.connect(func(index: int): outfit = CharacterStyle.preset(index); _controls(); _refresh())
	_label("Começar com uma combinação")
	choices.add_child(presets)
	_choice("Acessório de cabeça", "hat", CharacterStyle.HEADWEAR, ["Sem acessório", "Boné", "Gorro", "Chapéu", "Capacete", "Fones"])
	_choice("Cabelo", "hair", ["short", "bob", "bun", "none"], ["Curto", "Chanel", "Coque", "Sem cabelo"])
	_choice("Óculos", "glasses", ["none", "round"], ["Sem óculos", "Com óculos"])
	_choice("Mochila", "backpack", ["none", "pack"], ["Sem mochila", "Com mochila"])
	var jacket := CheckButton.new()
	jacket.text = "Usar jaqueta"
	jacket.button_pressed = outfit.get("jacket", false)
	jacket.toggled.connect(func(on: bool): outfit["jacket"] = on; _refresh())
	choices.add_child(jacket)
	_colors("Pele", "skin", CharacterStyle.SKIN_COLORS)
	_colors("Camiseta", "shirt", CharacterStyle.SHIRT_COLORS)
	_colors("Jaqueta", "jacket_color", CharacterStyle.SHIRT_COLORS)
	_colors("Calça", "pants", CharacterStyle.PANTS_COLORS)
	_colors("Sapatos", "shoes", CharacterStyle.HAT_COLORS)
	_colors("Acessório", "hat_color", CharacterStyle.HAT_COLORS)
	_colors("Cabelo", "hair_color", CharacterStyle.HAIR_COLORS)
	_colors("Óculos", "glasses_color", CharacterStyle.GLASSES_COLORS)
	_colors("Mochila", "backpack_color", CharacterStyle.BACKPACK_COLORS)
	var random_button := Button.new()
	random_button.text = "Sortear combinação"
	random_button.pressed.connect(func(): outfit = CharacterStyle.random_outfit(); _controls(); _refresh())
	choices.add_child(random_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(status)
	var save := Button.new()
	save.text = "SALVAR E VOLTAR"
	save.custom_minimum_size.y = 46
	save.pressed.connect(_save)
	choices.add_child(save)
	var back := Button.new()
	back.text = "Voltar sem salvar"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	choices.add_child(back)

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	choices.add_child(label)

func _choice(title: String, key: String, values: Array, labels: Array) -> void:
	_label(title)
	var option := OptionButton.new()
	for i in values.size():
		option.add_item(labels[i])
		if values[i] == outfit.get(key):
			option.select(i)
	option.item_selected.connect(func(i: int): outfit[key] = values[i]; _refresh())
	choices.add_child(option)

func _colors(title: String, key: String, colors: Array) -> void:
	_label(title)
	var row := HBoxContainer.new()
	choices.add_child(row)
	for color: Color in colors:
		var button := Button.new()
		button.custom_minimum_size = Vector2(25, 25)
		button.tooltip_text = title + " #" + color.to_html(false)
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(5)
		if color.to_html() == outfit.get(key, ""):
			style.set_border_width_all(2)
			style.border_color = Color.WHITE
		button.add_theme_stylebox_override("normal", style)
		button.pressed.connect(func(): outfit[key] = color.to_html(); _controls(); _refresh())
		row.add_child(button)

func _refresh() -> void:
	if is_instance_valid(visual):
		preview_root.remove_child(visual)
		visual.queue_free()
	var shown := outfit.duplicate(true)
	if preview_police:
		shown = CharacterStyle.police_outfit()
		shown["skin"] = outfit["skin"]
	visual = ModularCharacter.build(shown)
	preview_root.add_child(visual)
	anim = ModularCharacter.animation_player(visual)
	ModularCharacter.play_motion(anim, 0.0 if motion == "idle" else (1.6 if motion == "walk" else 4.6), motion == "idle")
	if status:
		status.text = "Uniforme reservado à polícia. Sua aparência civil será salva." if preview_police else "Cores e acessórios também aparecem nos civis da cidade."

func _save() -> void:
	if CharacterStyle.save_player_outfit(outfit) == OK:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	else:
		status.text = "Não foi possível salvar. Tente novamente."

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
