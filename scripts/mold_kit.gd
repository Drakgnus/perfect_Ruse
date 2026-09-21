extends Control

# Tela de pre-partida, irma do guarda-roupa: o jogador escolhe os moldes que
# leva no bolso. O que nao estiver aqui ainda pode ser copiado na rua (C).

var picked: Array[String] = []
var preview_root: Node3D
var preview_prop: Node3D
var preview_type := ""
var list: VBoxContainer
var status: Label
var rows := {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	picked = MoldLoadout.selected()
	preview_type = picked[0] if not picked.is_empty() else ""
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
	title.text = "MOLDES DE BOLSO"
	title.add_theme_font_size_override("font_size", 30)
	left.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Escolha %d objetos para levar prontos. Na partida, segure o BOTÃO DIREITO para abrir a roda e trocar entre eles." % MoldLoadout.SLOTS
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(subtitle)
	_build_preview(left)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 380
	layout.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_controls()
	_refresh_preview()
	if "--capture-molds" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _build_preview(parent: Control) -> void:
	var view_container := SubViewportContainer.new()
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container.stretch = true
	parent.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view_container.add_child(viewport)
	preview_root = Node3D.new()
	viewport.add_child(preview_root)
	var camera := Camera3D.new()
	camera.position = Vector3(1.7, 1.3, 2.6)
	preview_root.add_child(camera)
	camera.look_at(Vector3(0, 0.45, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
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
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 0.8
	cylinder.height = 0.04
	ground.position.y = -0.02
	ground.mesh = cylinder
	ground.material_override = Palette.flat_material(Palette.SIGN)
	preview_root.add_child(ground)

func _controls() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	rows.clear()
	var header := Label.new()
	header.text = "NO BOLSO: %d de %d" % [picked.size(), MoldLoadout.SLOTS]
	header.add_theme_font_size_override("font_size", 20)
	list.add_child(header)
	for prop_type in MoldLoadout.catalog():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var toggle := CheckButton.new()
		toggle.text = _label_for(prop_type)
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.button_pressed = picked.has(prop_type)
		toggle.toggled.connect(func(on: bool): _toggle(prop_type, on))
		row.add_child(toggle)
		rows[prop_type] = toggle
		var look := Button.new()
		look.text = "Ver"
		look.pressed.connect(func(): preview_type = prop_type; _refresh_preview())
		row.add_child(look)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#9ad0ff"))
	list.add_child(status)
	_update_status()
	var reset := Button.new()
	reset.text = "Voltar ao padrão"
	reset.pressed.connect(func(): picked = MoldLoadout.sanitize(MoldLoadout.DEFAULT); _controls(); _refresh_preview())
	list.add_child(reset)
	var save := Button.new()
	save.text = "SALVAR E VOLTAR"
	save.custom_minimum_size.y = 46
	save.pressed.connect(_save)
	list.add_child(save)
	var back := Button.new()
	back.text = "Voltar sem salvar"
	back.pressed.connect(_leave)
	list.add_child(back)

# O bolso tem tamanho fixo: marcar o quarto molde tiraria o mais antigo sem
# aviso, entao o clique e recusado e a caixa volta sozinha.
func _toggle(prop_type: String, on: bool) -> void:
	if on:
		if picked.size() >= MoldLoadout.SLOTS:
			rows[prop_type].set_pressed_no_signal(false)
			_update_status("Bolso cheio: desmarque um molde antes de escolher %s." % _label_for(prop_type))
			return
		if not picked.has(prop_type):
			picked.append(prop_type)
		preview_type = prop_type
		_refresh_preview()
	else:
		if picked.size() <= 1:
			rows[prop_type].set_pressed_no_signal(true)
			_update_status("Deixe pelo menos um molde no bolso.")
			return
		picked.erase(prop_type)
	_controls()

func _update_status(message := "") -> void:
	if status == null:
		return
	if message != "":
		status.text = message
		return
	var names: Array[String] = []
	for prop_type in picked:
		names.append(_label_for(prop_type))
	status.text = "Na roda: %s. Os outros objetos continuam sendo copiados na rua com C." % ", ".join(names)

func _label_for(prop_type: String) -> String:
	return String(PropLabels.MAP.get(prop_type, prop_type.to_upper()))

func _refresh_preview() -> void:
	if preview_root == null:
		return
	if is_instance_valid(preview_prop):
		preview_root.remove_child(preview_prop)
		preview_prop.queue_free()
		preview_prop = null
	if preview_type == "":
		return
	preview_prop = CityBuilder.create_prop(preview_type)
	preview_root.add_child(preview_prop)

func _save() -> void:
	if MoldLoadout.save(picked) == OK:
		_leave()
	else:
		_update_status("Não foi possível salvar. Tente novamente.")

func _leave() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _capture() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://mold-kit-preview.png")
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
