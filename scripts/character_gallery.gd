extends Node3D

func _ready() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 3.5, 15)
	camera.look_at(Vector3(0, 3.5, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.8
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#263646")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.0
	add_child(light)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var moving: Array[AnimationPlayer] = []
	for i in 15:
		var outfit := CharacterStyle.preset(i)
		if i >= 12:
			outfit = CharacterStyle.police_outfit()
			outfit["skin"] = CharacterStyle.SKIN_COLORS[(i - 12) * 2].to_html()
		var model := ModularCharacter.build(outfit)
		model.position = Vector3((i % 5 - 2) * 2.1, (2 - i / 5) * 2.5, 0)
		add_child(model)
		var ap := ModularCharacter.animation_player(model)
		ModularCharacter.play_motion(ap, 0, true)
		moving.append(ap)
		var label := Label3D.new()
		label.text = CharacterStyle.PRESET_NAMES[i] if i < 12 else "Polícia"
		label.position = model.position + Vector3(0, -0.18, 0.35)
		label.font_size = 32
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	if "--capture-gallery" in OS.get_cmdline_user_args():
		for clip in ["idle", "walk", "run"]:
			for ap in moving:
				ModularCharacter.play_motion(ap, 0 if clip == "idle" else (1.6 if clip == "walk" else 4.6), clip == "idle")
			await get_tree().create_timer(0.7).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://gallery-" + clip + ".png")
		get_tree().quit()
