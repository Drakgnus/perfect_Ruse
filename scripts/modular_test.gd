extends Node3D

# Teste de personagem modular: instancia o hero.glb varias vezes com cores
# diferentes e acessorios ligados/desligados, todos andando. Prova o conceito
# de "1 modelo -> muitos personagens" por recolor + toggle.

const HERO := "res://assets/models/characters/modular/hero.glb"

func _ready() -> void:
	_build_env()

	# Body/Boot tem 2 superficies: "_base" (recoloravel) + detalhe fixo
	# (olhos/boca na pele; sola/cadarco na bota). O recolor atinge SO a base.
	# Cada variante toca um clipe diferente para validar a biblioteca de animacoes.
	var variants := [
		# completo, azul + botas amarelas — andando
		{"anim": "walk", "colors": {"Cap": Color("#2f6fe0"), "Pants": Color("#2f6fe0"), "Body": Color("#e8b58f"), "Boot_L": Color("#f2b719"), "Boot_R": Color("#f2b719")}},
		# SEM bone, calca verde, pele morena, botas vermelhas — correndo
		{"anim": "run", "hide": ["Cap"], "colors": {"Pants": Color("#4a9e5a"), "Glasses": Color("#222222"), "Body": Color("#c98a5e"), "Boot_L": Color("#b03a2e"), "Boot_R": Color("#b03a2e")}},
		# SEM oculos, cap vermelho, botas azuis — parando
		{"anim": "walk_stop", "hide": ["Glasses"], "colors": {"Cap": Color("#c0392b"), "Pants": Color("#2e3b55"), "Body": Color("#f0c8a0"), "Boot_L": Color("#3d7ea6"), "Boot_R": Color("#3d7ea6")}},
		# cap roxo, calca laranja, pele escura, botas verdes — virando
		{"anim": "turn_left", "colors": {"Cap": Color("#7d5ba6"), "Pants": Color("#d47a3f"), "Glasses": Color("#e0a83d"), "Body": Color("#8d5a3c"), "Boot_L": Color("#2e8b57"), "Boot_R": Color("#2e8b57")}},
		# cap verde, calca cinza, botas brancas — swagger
		{"anim": "swagger", "colors": {"Cap": Color("#2e8b57"), "Pants": Color("#556070"), "Glasses": Color("#c0392b"), "Body": Color("#a56b43"), "Boot_L": Color("#e8e4dc"), "Boot_R": Color("#e8e4dc")}},
	]

	var x := -(variants.size() - 1) * 0.8
	for v in variants:
		_spawn(v, Vector3(x, 0, 0))
		x += 1.6

	# screenshot opcional (para validacao automatica)
	if "--shot" in OS.get_cmdline_args() or "--shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("D:/Jogos/MeuJogo/Personagens/blender_work/previews/game_shot.png")
		get_tree().quit()
	# gravacao de sequencia de frames (vira GIF depois)
	if "--record" in OS.get_cmdline_args() or "--record" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.3).timeout
		for i in 40:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("D:/Jogos/MeuJogo/Personagens/blender_work/frames/rec_f%02d.png" % i)
			await get_tree().process_frame
			await get_tree().process_frame
		get_tree().quit()

func _spawn(v: Dictionary, pos: Vector3) -> void:
	var scene := load(HERO) as PackedScene
	if scene == null:
		push_error("hero.glb nao encontrado")
		return
	var inst := scene.instantiate() as Node3D
	add_child(inst)
	inst.position = pos
	inst.rotation.y = 0.0  # virado para a camera

	# animacao em loop — toca o clipe pedido (fallback: primeiro da lista)
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var wanted := String(v.get("anim", "walk"))
		var chosen := ""
		for n in ap.get_animation_list():
			if n == "RESET":
				continue
			if chosen == "":
				chosen = n
			if n == wanted or n.ends_with("/" + wanted):
				chosen = n
				break
		if chosen != "":
			var a := ap.get_animation(chosen)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
			ap.play(chosen)
		print("anims=", ap.get_animation_list(), " tocando=", chosen)

	# recolor por peca — em pecas com zonas, recolore SO a superficie "_base"
	var colors: Dictionary = v.get("colors", {})
	for mesh_name in colors:
		var mi := inst.find_child(mesh_name, true, false)
		if mi is MeshInstance3D:
			_recolor(mi, colors[mesh_name])

	# esconder acessorios
	for hide_name in v.get("hide", []):
		var mi := inst.find_child(hide_name, true, false)
		if mi:
			mi.visible = false

# Recolore a peca: se a malha tem superficie "_base" (peca com zonas), troca so
# ela e preserva o detalhe (olhos/boca, sola preta). Senao, override geral.
func _recolor(mi: MeshInstance3D, c: Color) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	var base_idx := -1
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m and m.resource_name.contains("_base"):
			base_idx = i
			break
	if base_idx >= 0:
		mi.set_surface_override_material(base_idx, _mat(c))
	else:
		mi.material_override = _mat(c)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func _build_env() -> void:
	# chao
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#8a9099")
	ground.mesh.surface_set_material(0, gm)
	add_child(ground)

	# luz
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-40), 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#c5d2e0")
	env.ambient_light_color = Color("#ffffff")
	env.ambient_light_energy = 0.4
	env_node.environment = env
	add_child(env_node)

	# camera
	var cam := Camera3D.new()
	var cpos := Vector3(0, 1.15, 4.0)
	cam.position = cpos
	cam.look_at_from_position(cpos, Vector3(0, 0.95, 0), Vector3.UP)
	cam.fov = 55.0
	add_child(cam)
