extends CharacterBase

# Ladrao controlado pelo jogador.
# E: rouba (NPC instantaneo; loja/ATM canalizado) ou resgata esconderijo.
# Q: esconde o dinheiro camuflado num objeto proximo.
# F: copia roupa/rota de um NPC. R: segue a rota copiada (blend).

# Andar e o padrao; Shift corre. O limiar de animacao em modular_character
# (play_motion) troca walk->run em 3.5, entao WALK fica abaixo e RUN acima —
# assim o boneco anda de verdade em vez de correr o tempo todo.
const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const SPEED := RUN_SPEED   # mantido para nao quebrar referencias antigas

func current_speed() -> float:
	return RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
const BLEND_SPEED := 1.25
const MOUSE_SENSITIVITY := 0.0025
const PLACE_RANGE := 6.0
const CAM_OFFSET := Vector3(0, 3.2, 7.5)   # posicao da camera atras/acima
const GHOST_VALID_COLOR := Color(0.42, 1.0, 0.55, 0.45)
const GHOST_INVALID_COLOR := Color(1.0, 0.35, 0.3, 0.45)

var game: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var blending := false
var city_route := PackedVector3Array()
var route_index := 0
# "thief" ou "police" — quando preso, o jogador e convertido e continua na
# partida do lado da policia (GDD: nao ha eliminacao permanente).
var team := "thief"
var police_target: Node3D
var police_action := ""
var police_total := 0.0
var police_left := 0.0

# Modo de colocacao (prop hunt): "" | "stash" | "decoy"
const PLACEMENT_SECONDS := 0.8
var placement_mode := ""
var placement_requested := false
var placement_active := false
var placement_elapsed := 0.0
var placement_point := Vector3.ZERO
var placement_ring: Node3D
var ghost: Node3D
var ghost_material: StandardMaterial3D
var ghost_position := Vector3.ZERO
var ghost_valid := false
var ghost_bounds := AABB()
var ghost_basis := Basis.IDENTITY
var placement_basis := Basis.IDENTITY
var placement_spin := 0.0
var placement_face := 0
var edit_requested := false
# Roda de moldes (botao direito fora do modo de colocacao). O mouse fica
# capturado, entao o setor vem do movimento acumulado desde a abertura.
var wheel_open := false
var wheel_offset := Vector2.ZERO
var wheel_entries: Array[String] = []
var wheel_index := -1
var editing_decoy: Node3D
var previous_mold := ""
var has_disguise := false
var route_home := Vector3.ZERO
var route_phase := 0.0
var using_local_route := false
var route_axis := Vector3.FORWARD

var channel_target: Node3D
var channel_total := 0.0
var channel_left := 0.0
var disguise_victim: CharacterBase   # NPC cuja identidade o jogador assumiu

func _ready() -> void:
	is_thief = true
	game = get_parent()
	# O bolso escolhido antes da partida ja entra equipado: sem isso o jogador
	# comecava obrigado a achar um objeto na rua antes da primeira isca.
	copied_prop_type = MoldLoadout.starting_mold()
	add_to_group("player")
	add_to_group("thieves")
	add_to_group("friskable")
	build_character(CharacterStyle.player_outfit())
	# Anel discreto no chao para o jogador se identificar no meio da multidao.
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 0.6
	ring_mesh.material = Palette.flat_material(Palette.PLAYER_RING)
	ring.mesh = ring_mesh
	ring.position.y = 0.05
	add_child(ring)
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.5, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = CAM_OFFSET
	camera.rotation_degrees = Vector3(-16, 0, 0)
	camera.current = true
	camera_pivot.add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# debug: captura de tela automatica para validacao (--shot na linha de comando)
	if "--shot" in OS.get_cmdline_args() or "--shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("D:/Jogos/MeuJogo/Personagens/blender_work/previews/player_shot.png")
		get_tree().quit()

func _notification(what: int) -> void:
	# Solta o cursor quando a janela perde o foco (tecla Windows, Alt+Tab,
	# ferramenta de captura). Sem isto o mouse fica confinado na janela do jogo
	# mesmo com o jogo em segundo plano.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if game.phase != "playing":
		return
	if event is InputEventMouseMotion and wheel_open:
		# Enquanto a roda esta aberta o mouse escolhe o setor, nao gira a camera.
		wheel_offset += event.relative
		_track_wheel()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Orbit the camera, not the walking body, while following a destination.
		if blending:
			camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		else:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -0.8, 0.35)
	if event.is_action_pressed("ui_cancel"):
		if wheel_open:
			_close_wheel(false)
			return
		if placement_mode != "":
			_exit_placement()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V and team == "thief":
		edit_requested = true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		if wheel_open:
			_close_wheel(true)
		return
	if event is InputEventMouseButton and event.pressed:
		if placement_mode == "" and event.button_index == MOUSE_BUTTON_RIGHT:
			_open_wheel()
			return
		if placement_mode != "" and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if not placement_active:
				var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				if event.shift_pressed:
					placement_face = posmod(placement_face + step, 4)
				else:
					placement_spin += step * deg_to_rad(15.0)
			return
		if placement_mode != "" and event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_placement()
		elif placement_mode != "" and event.button_index == MOUSE_BUTTON_RIGHT:
			_exit_placement()
		# Recaptura SO no clique esquerdo e SO com a janela em foco. Antes
		# qualquer botao recapturava, o que anulava o Esc: o primeiro clique do
		# jogador era engolido e o cursor voltava a ficar preso na janela.
		elif event.button_index == MOUSE_BUTTON_LEFT and get_window().has_focus():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_update_camera_collision()
	if game.phase != "playing":
		_close_wheel(false)
		_exit_placement()
		velocity = Vector3.ZERO
		return
	if game.route_selecting:
		velocity = Vector3.ZERO
		return
	if frozen:
		_close_wheel(false)
		_cancel_channel()
		_stop_blend()
		_exit_placement()
		return
	if team == "police":
		_police_physics(delta)
		return
	if edit_requested:
		edit_requested = false
		_start_decoy_edit()
	if placement_requested:
		placement_requested = false
		_update_ghost()
		_begin_placement()
	if placement_active:
		if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length_squared() > 0.01:
			_exit_placement()
		else:
			velocity = Vector3.ZERO
			_tick_placement(delta)
			return
	if Input.is_action_just_pressed("take_outfit"):
		_take_npc_outfit()
	if Input.is_action_just_pressed("blend_route"):
		_toggle_blend()
	if Input.is_action_just_pressed("rob"):
		_stop_blend()
		_exit_placement()
		_interact()
	if Input.is_action_just_pressed("copy_prop"):
		game.copy_prop(self)
		if placement_mode != "":
			_refresh_ghost_shape()
	if Input.is_action_just_pressed("hide_money"):
		_stop_blend()
		_cancel_channel()
		_toggle_placement("stash")
	if Input.is_action_just_pressed("place_decoy"):
		_cancel_channel()
		_toggle_placement("decoy")
	if Input.is_action_just_pressed("ability"):
		game.use_ability(self)
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_vector.length_squared() > 0.01:
		_stop_blend()
		_cancel_channel()
	_tick_channel(delta)
	if placement_mode != "":
		_update_ghost()
	if blending:
		_follow_copied_route(delta)
		return
	var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	var move_speed := current_speed()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = -1.0
	move_and_slide()

# Encurta a camera quando um predio fica entre ela e o jogador (camada 3).
func _update_camera_collision() -> void:
	if camera_pivot == null:
		return
	var origin := camera_pivot.global_position
	var desired := camera_pivot.to_global(CAM_OFFSET)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, desired)
	query.collision_mask = 4   # so predios
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		camera.global_position = desired
	else:
		var safe: Vector3 = origin + (hit["position"] - origin) * 0.9
		camera.global_position = safe

func is_channeling() -> bool:
	return channel_target != null or police_target != null

# --- Lado da policia (apos conversao) ----------------------------------------

func become_police() -> void:
	_close_wheel(false)
	team = "police"
	is_thief = false
	remove_from_group("thieves")
	remove_from_group("friskable")
	add_to_group("police")
	_cancel_channel()
	_exit_placement()
	_stop_blend()
	# Devolve a identidade roubada — o NPC volta para a rua.
	if disguise_victim != null and is_instance_valid(disguise_victim):
		disguise_victim.restore()
		disguise_victim = null
	has_disguise = false
	suspicion = 0.0
	set_outfit(CharacterStyle.uniform_for(character_outfit))
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.13
	beacon_mesh.bottom_radius = 0.13
	beacon_mesh.height = 0.16
	beacon_mesh.material = Palette.flat_material(Palette.POLICE_BEACON)
	beacon.mesh = beacon_mesh
	beacon.position.y = body_height + 0.75
	add_child(beacon)

# O jogo chama estes dois metodos sobre TODO o grupo "police". Enquanto so a IA
# estava nele, bastava existirem em police.gd. Com o jogador convertido entrando
# no grupo, a ausencia deles quebrava a partida a cada alerta com
# "Nonexistent function 'respond_to_alert'". Aqui viram informacao util para o
# policial humano, em vez de no-op.
func respond_to_alert(origin: Vector3) -> void:
	if team != "police":
		return
	game.hud.toast("ALERTA: ROUBO NA REGIAO %s — VA ATE LA" % game.region_name(origin), 3.5)

func witness_crime(thief: CharacterBase) -> void:
	if team != "police" or not is_instance_valid(thief):
		return
	game.hud.toast("FLAGRANTE! VOCE VIU UM ROUBO — E PARALISA E REVISTA", 3.5)

func _police_physics(delta: float) -> void:
	if Input.is_action_just_pressed("rob"):
		_police_interact()
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_vector.length_squared() > 0.01:
		_cancel_police_action()
	_tick_police_action(delta)
	if police_target != null:
		velocity = Vector3.ZERO
		return
	var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	var move_speed := current_speed()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = -1.0
	move_and_slide()

func _police_interact() -> void:
	if police_target != null:
		_cancel_police_action()
		return
	var interactable: Dictionary = game.find_police_interactable(self)
	if interactable.is_empty():
		return
	police_target = interactable["node"]
	police_action = String(interactable["kind"])
	if police_action == "frisk":
		police_target.set_frozen(true)
		police_total = 3.0
	else:
		police_total = 1.6
	police_left = police_total

func _tick_police_action(delta: float) -> void:
	if police_target == null:
		return
	if not is_instance_valid(police_target) or global_position.distance_to(police_target.global_position) > 3.2:
		_cancel_police_action()
		return
	police_left -= delta
	if police_left <= 0.0:
		var node := police_target
		var action := police_action
		police_target = null
		police_action = ""
		if action == "frisk":
			game.resolve_frisk(self, node)
		else:
			game.recover_stash(self, node)

func _cancel_police_action() -> void:
	if police_target != null and is_instance_valid(police_target) and police_action == "frisk":
		police_target.set_frozen(false)
	police_target = null
	police_action = ""

# --- Modo de colocacao (fantasma segue a mira; clique confirma) --------------

# --- Roda de moldes -------------------------------------------------------

func _open_wheel() -> void:
	if wheel_open or team != "thief" or frozen or game.phase != "playing" or game.route_selecting:
		return
	wheel_entries = MoldLoadout.wheel_entries(copied_prop_type)
	if wheel_entries.is_empty():
		return
	wheel_open = true
	wheel_offset = Vector2.ZERO
	wheel_index = -1
	var labels: Array[String] = []
	for prop_type in wheel_entries:
		labels.append(game.prop_label(prop_type))
	if game.hud and game.hud.mold_wheel:
		game.hud.mold_wheel.open(wheel_entries, labels, wheel_entries.find(copied_prop_type))

func _track_wheel() -> void:
	wheel_index = MoldLoadout.sector_at(wheel_offset, wheel_entries.size())
	if game.hud and game.hud.mold_wheel:
		game.hud.mold_wheel.track(wheel_offset, wheel_index)

# Soltar o botao dentro do raio morto e desistencia: o molde atual fica.
func _close_wheel(confirm: bool) -> void:
	if not wheel_open:
		return
	var choice := ""
	if confirm and wheel_index >= 0 and wheel_index < wheel_entries.size():
		choice = wheel_entries[wheel_index]
	wheel_open = false
	wheel_offset = Vector2.ZERO
	wheel_index = -1
	wheel_entries.clear()
	if game.hud and game.hud.mold_wheel:
		game.hud.mold_wheel.close()
	if choice != "" and choice != copied_prop_type:
		copied_prop_type = choice
		if game.hud:
			game.hud.toast("MOLDE: %s" % game.prop_label(choice))

func _toggle_placement(mode: String) -> void:
	_close_wheel(false)
	if placement_mode == mode:
		_exit_placement()
		return
	_exit_placement()
	if not game.can_start_placement(self, mode):
		return
	placement_mode = mode
	_create_ghost()

func _create_ghost() -> void:
	ghost = CityBuilder.create_prop(copied_prop_type)
	ghost.name = "PlacementGhost"
	ghost_bounds = ModelLibrary.combined_aabb(ghost, Transform3D.IDENTITY)
	ghost.collision_layer = 0
	ghost.collision_mask = 0
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = GHOST_VALID_COLOR
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ModelLibrary.apply_ghost_material(ghost, ghost_material)
	game.add_child(ghost)
	_update_ghost()

func _refresh_ghost_shape() -> void:
	# Trocou o molde no meio do modo de colocacao: recria o fantasma.
	var mode := placement_mode
	_exit_placement()
	placement_mode = mode
	_create_ghost()

func _aim_surface(ignore_placed: bool) -> Dictionary:
	var center := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	var ignored: Array[RID] = []
	for child in game.get_children():
		if child is CharacterBase:
			ignored.append(child.get_rid())
	for record in game.placed_objects:
		if is_instance_valid(record["node"]) and (ignore_placed or record["owner"] != self or int(record["amount"]) > 0):
			ignored.append(record["node"].get_rid())
	query.exclude = ignored
	return get_world_3d().direct_space_state.intersect_ray(query)

func _start_decoy_edit() -> void:
	if placement_active:
		return
	var hit := _aim_surface(false)
	if hit.is_empty() or not game.can_move_decoy(self, hit["collider"]):
		game.hud.toast("MIRE UMA ISCA SUA E APERTE V PARA MOVER")
		return
	var target: Node3D = hit["collider"]
	if global_position.distance_to(target.global_position) > PLACE_RANGE:
		game.hud.toast("APROXIME-SE DA ISCA PARA MOVER")
		return
	_exit_placement()
	previous_mold = copied_prop_type
	editing_decoy = target
	copied_prop_type = String(target.get_meta("prop_type"))
	placement_mode = "move_decoy"
	_create_ghost()

func _update_ghost() -> void:
	if not is_instance_valid(ghost):
		return
	var hit := _aim_surface(true)
	ghost_valid = false
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		if normal.length_squared() > 0.5:
			var pose := PropPlacement.on_surface(point, normal, ghost_bounds, placement_spin, placement_face)
			ghost_position = pose.origin
			ghost_basis = pose.basis
			ghost.transform = pose
			ghost_valid = global_position.distance_to(point) <= PLACE_RANGE and game.is_placement_position_valid(ghost_position)
	ghost.visible = not hit.is_empty()
	ghost_material.albedo_color = GHOST_VALID_COLOR if ghost_valid else GHOST_INVALID_COLOR

func _confirm_placement() -> void:
	# Input callbacks never perform physics queries. Commit intent in physics.
	if placement_mode != "" and not placement_active:
		placement_requested = true

func _begin_placement() -> void:
	if placement_mode == "" or placement_active:
		return
	if not ghost_valid or not game.can_start_placement(self, placement_mode) or not game.is_placement_position_valid(ghost_position):
		game.hud.toast("MIRE UMA SUPERFÍCIE A ATÉ 6 METROS")
		return
	if placement_mode == "move_decoy" and not game.can_move_decoy(self, editing_decoy):
		_exit_placement()
		return
	placement_active = true
	placement_elapsed = 0.0
	placement_point = ghost_position
	placement_basis = ghost_basis
	_cancel_channel()
	_stop_blend()
	placement_ring = PlacementFeedback.progress_ring(self)
	PlacementFeedback.update_ring(placement_ring, 0.0)

func _tick_placement(delta: float) -> void:
	if not placement_active:
		return
	if frozen or team != "thief" or game.phase != "playing" or not game.can_start_placement(self, placement_mode):
		_exit_placement()
		return
	placement_elapsed += delta
	PlacementFeedback.update_ring(placement_ring, clampf(placement_elapsed / PLACEMENT_SECONDS, 0.0, 1.0))
	if placement_elapsed < PLACEMENT_SECONDS:
		return
	var mode := placement_mode
	var position_chosen := placement_point
	var orientation := placement_basis
	var target := editing_decoy
	_exit_placement()
	# Keep world bounds valid at completion; overlap is deliberately allowed.
	if not game.is_placement_position_valid(position_chosen):
		game.hud.toast("POSIÇÃO FORA DO MAPA — SEU DINHEIRO FOI MANTIDO")
		return
	if mode == "move_decoy":
		if not game.move_decoy(self, target, Transform3D(orientation, position_chosen)):
			game.hud.toast("NÃO FOI POSSÍVEL MOVER ESSA ISCA")
	elif mode == "stash":
		game.hide_money_at(self, position_chosen, orientation)
	else:
		game.place_decoy_at(self, position_chosen, orientation)

func _exit_placement() -> void:
	if placement_mode == "move_decoy":
		copied_prop_type = previous_mold
	editing_decoy = null
	previous_mold = ""
	placement_spin = 0.0
	placement_face = 0
	edit_requested = false
	placement_mode = ""
	placement_requested = false
	placement_active = false
	placement_elapsed = 0.0
	if is_instance_valid(placement_ring):
		placement_ring.queue_free()
	placement_ring = null
	if current_model != null:
		current_model.position.y = 0.0
		current_model.rotation.x = 0.0
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func channel_progress() -> float:
	if police_target != null and police_total > 0.0:
		return 1.0 - (police_left / police_total)
	if channel_total <= 0.0:
		return 0.0
	return 1.0 - (channel_left / channel_total)

func _interact() -> void:
	if channel_target != null:
		_cancel_channel()
		return
	var interactable: Dictionary = game.find_interactable(self)
	if interactable.is_empty():
		return
	var node: Node3D = interactable["node"]
	match String(interactable["kind"]):
		"npc":
			game.rob_npc(self, node)
		"stash":
			game.retrieve_stash(self, node)
		"decoy":
			game.remove_decoy(self, node)
		"target":
			channel_target = node
			channel_total = game.channel_time_for(self, float(node.get_meta("channel_time")))
			channel_left = channel_total

func _tick_channel(delta: float) -> void:
	if channel_target == null:
		return
	if not is_instance_valid(channel_target) or global_position.distance_to(channel_target.global_position) > 3.2:
		_cancel_channel()
		return
	# Se um policial entra na linha de visao durante o roubo, e flagrante: cancela.
	if game.seeing_officer(self) != null:
		_cancel_channel()
		game.check_robbery_vision(self)
		return
	channel_left -= delta
	if channel_left <= 0.0:
		var target := channel_target
		channel_target = null
		game.rob_target(self, target)

func _cancel_channel() -> void:
	channel_target = null
	channel_left = 0.0

func _take_npc_outfit() -> void:
	var nearest: CharacterBase
	var distance := 2.3
	for npc in get_tree().get_nodes_in_group("civilians"):
		if npc.stolen:
			continue
		var candidate_distance := global_position.distance_to(npc.global_position)
		if candidate_distance < distance:
			nearest = npc
			distance = candidate_distance
	if nearest == null:
		game.hud.toast("CHEGUE PERTO DE UM NPC (NUM BECO) PARA ROUBAR A ROUPA DELE")
		return
	# Solta o disfarce anterior: aquele NPC volta para a rua.
	if disguise_victim != null and is_instance_valid(disguise_victim):
		disguise_victim.restore()
	has_disguise = true
	route_home = nearest.home
	route_phase = nearest.phase
	# Assume a identidade: veste a roupa E o NPC "some" (nao pode haver dois iguais).
	set_outfit(nearest.character_outfit)
	nearest.knock_out()
	disguise_victim = nearest
	game.relieve_by_disguise(self)   # trocar de roupa acalma o nervosismo
	game.hud.toast("VOCE ROUBOU A ROUPA E ASSUMIU O LUGAR DELE — SE MISTURE")
	game.set_blend_status(false)

func _toggle_blend() -> void:
	if blending:
		_stop_blend()
		return
	_cancel_channel()
	_exit_placement()
	game.begin_route_selection()

func start_city_route(points: PackedVector3Array) -> void:
	city_route = points
	route_index = 0
	blending = not points.is_empty()
	game.set_blend_status(blending)

func _stop_blend() -> void:
	if blending:
		blending = false
		# Keep the view unchanged, then make manual WASD relative to that view.
		rotation.y += camera_pivot.rotation.y
		camera_pivot.rotation.y = 0.0
		city_route.clear()
		game.set_blend_status(false)

func _follow_copied_route(_delta: float) -> void:
	while route_index < city_route.size() and Vector2(global_position.x - city_route[route_index].x, global_position.z - city_route[route_index].z).length() < 0.35:
		route_index += 1
	if route_index >= city_route.size():
		_stop_blend()
		velocity = Vector3.ZERO
		game.hud.toast("VOCÊ CHEGOU AO DESTINO")
		return
	var target_position := city_route[route_index]
	if CityRoutes.car_approaching(self, target_position):
		velocity = Vector3.ZERO
		return
	var direction := global_position.direction_to(target_position)
	velocity.x = direction.x * BLEND_SPEED
	velocity.z = direction.z * BLEND_SPEED
	velocity.y = -1.0
	# The model faces its velocity in _process; rotating the body here locks
	# the camera to the route and was the source of the reported camera issue.
	move_and_slide()

func _process(delta: float) -> void:
	super._process(delta)
	if placement_active and current_model != null:
		var bend := sin(PI * clampf(placement_elapsed / PLACEMENT_SECONDS, 0.0, 1.0))
		current_model.position.y = -0.08 * bend
		current_model.rotation.x = 0.12 * bend
	if current_model == null:
		return
	var model := current_model.get_node_or_null("Citizen") as Node3D
	if model == null:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.15 and not frozen:
		var direction := global_transform.basis.inverse() * flat.normalized()
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-12.0 * delta))
