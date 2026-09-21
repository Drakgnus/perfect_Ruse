extends Node3D

# GameManager do Perfect Ruse. Toda a regra de partida vive aqui, com APIs
# claras (rob_npc, rob_target, hide_money, resolve_frisk...) para facilitar a
# futura camada multiplayer: os personagens pedem, o manager decide.

const PlayerScript = preload("res://scripts/player.gd")
const NpcScript = preload("res://scripts/npc.gd")
const ThiefBotScript = preload("res://scripts/thief_bot.gd")
const PoliceScript = preload("res://scripts/police.gd")
const TrafficCarScript = preload("res://scripts/traffic_car.gd")

const CIVILIAN_COUNT := 64
const TRAFFIC_COUNT := 14

const LIGHT_GREEN := 8.0    # segundos de verde por eixo
const LIGHT_YELLOW := 2.0   # segundos de amarelo antes de trocar

const MONEY_GOAL := 1500
const NPC_ROB_VALUE := 100
# Nervosismo: carregar MUITO dinheiro por MUITO TEMPO deixa o ladrao nervoso
# (nao e por ficar sem roubar). Acima do limite, sobe devagar; esconder o
# dinheiro ou trocar de roupa alivia.
const MONEY_NERVOUS_THRESHOLD := 300   # abaixo disso, tranquilo
const NERVOUS_RATE := 2.2              # %/s acima do limite
const CALM_RATE := 7.0                 # %/s quando abaixo do limite
const CLOTHES_RELIEF := 55.0           # alivio ao trocar de roupa
const ALERT_DURATION := 8.0
const CHECKED_DURATION := 20.0      # GDD: marca temporaria pos-revista
const COPY_RANGE := 3.0
const MAX_DECOYS_PER_THIEF := 3
const STASH_SUSPECT_RADIUS := 12.0
const STASH_RECENT_WINDOW_MS := 45000
const VISION_RANGE := 22.0            # alcance de visao do policial
const VISION_CONE_COS := 0.57         # cos(~55 graus): meia-abertura do cone
const ROBBERY_YIELD_DECAY := 0.7      # cada roubo do mesmo tipo rende 70% do anterior
const ROBBERY_YIELD_MIN := 0.35       # ainda vale a pena variar, sem zerar o alvo
const ROBBERY_YIELD_RECOVERY := 0.05  # recuperacao por segundo sem repetir o tipo


var routes := CityRoutes.new()
var pause_menu: CanvasLayer
var route_selecting := false
var phase := "playing"
var recovered_money := 0
var stats_stolen := 0
var stats_conversions := 0
var match_start_ms := 0
var alert_origin := Vector3.ZERO
var alert_until_ms := 0
var alert_started_ms := 0
# Objetos colocados por ladroes (estilo prop hunt): dinheiro disfarçado E iscas.
# Cada registro: { node, amount (0 = isca), owner, created_ms, claimed }
var placed_objects: Array[Dictionary] = []
var hud: GameHud
var minimap: Minimap
var player: CharacterBase
var audio: AudioManager
var alarm_targeting := false
var light_active_x := true
var light_sub := "green"          # "green" ou "yellow"
var light_timer := 0.0
var traffic_lights: Array[Dictionary] = []   # { material, is_x }
# Multiplicador de rendimento por tipo de alvo (npc, car, store, atm).
var robbery_yield_by_type: Dictionary[String, float] = {}

func _ready() -> void:
	randomize()
	match_start_ms = Time.get_ticks_msec()
	audio = AudioManager.new()
	add_child(audio)
	CityBuilder.build(self)
	for target in get_tree().get_nodes_in_group("robbable"):
		if target.get_meta("kind", "") in ["store", "atm"]:
			routes.add_destination(target.global_position)
	hud = GameHud.new()
	add_child(hud)
	minimap = Minimap.new()
	minimap.game = self
	hud.add_child(minimap)
	_spawn_characters()
	_spawn_traffic()
	pause_menu = preload("res://scripts/pause_menu.gd").new()
	pause_menu.game = self
	add_child(pause_menu)
	if "--shot" in OS.get_cmdline_user_args():
		_capture_debug_shots.call_deferred()

func _capture_debug_shots() -> void:
	# Ferramenta de dev: salva screenshots e encerra. Acionar com `-- --shot`.
	for i in 3:
		await get_tree().create_timer(1.2).timeout
		# Dev: traz um policial pra frente do jogador para a foto de aprovacao.
		if "--shot-police" in OS.get_cmdline_user_args():
			var pols := get_tree().get_nodes_in_group("police")
			if not pols.is_empty():
				pols[0].global_position = Vector3(1.2, 0.2, -3.0)
				pols[0].patrol_home = Vector3(1.2, 0.2, 10.0)  # anda em direcao a camera
				await get_tree().process_frame
		if i == 2 and "--shot-map" in OS.get_cmdline_user_args():
			alarm_targeting = true
			minimap.set_targeting(true)
			await get_tree().process_frame
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		var path := "user://shot_%d.png" % i
		image.save_png(path)
		print("SHOT_SAVED:", ProjectSettings.globalize_path(path))
	get_tree().quit()

func _spawn_characters() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0, 0.2, 0)
	player.ability = Abilities.random_ability()
	add_child(player)
	# NPCs espalhados pelas ruas/quarteireis do mapa maior.
	var npc_spots := _street_points(CIVILIAN_COUNT)
	for index in npc_spots.size():
		var npc := NpcScript.new()
		npc.name = "NPC_%d" % (index + 1)
		# Ha mais civis (64) do que pontos da malha de calcada: quem "da a volta"
		# no indice ganha um deslocamento lateral, senao dois civis nascem
		# exatamente no mesmo ponto (pego pelo routes_pause_integration).
		var point_count := routes.graph.get_point_count()
		var lap := index / point_count
		var spread := 1.1 * float(lap) * (1.0 if lap % 2 == 0 else -1.0)
		npc.position = routes.graph.get_point_position((index * 17) % point_count) + Vector3(spread, 0, spread * 0.6)
		npc.home = npc_spots[index]
		add_child(npc)
	var bot_spots := _street_points(6)
	for index in bot_spots.size():
		var bot := ThiefBotScript.new()
		bot.name = "ThiefBot_%d" % (index + 1)
		bot.position = bot_spots[index]
		bot.ability = Abilities.random_ability()
		add_child(bot)
	for index in 3:
		var officer := PoliceScript.new()
		officer.name = "Police_%d" % (index + 1)
		officer.position = [Vector3(-CityBuilder.ROAD_SPACING, 0.2, -CityBuilder.ROAD_SPACING), Vector3(CityBuilder.ROAD_SPACING, 0.2, CityBuilder.ROAD_SPACING), Vector3(CityBuilder.ROAD_SPACING, 0.2, -CityBuilder.ROAD_SPACING)][index]
		add_child(officer)

# --- Transito: carros dirigindo + semaforos ---------------------------------

func _spawn_traffic() -> void:
	var roads := CityBuilder.ROADS
	# Alguns carros em cada eixo, direcoes alternadas.
	for i in TRAFFIC_COUNT:
		var car := TrafficCarScript.new()
		car.name = "TrafficCar_%d" % i
		var is_x := i % 2 == 0
		var sign := 1.0 if (i / 2) % 2 == 0 else -1.0
		var road: float = roads[i % roads.size()]
		var start := randf_range(-CityBuilder.MAP_HALF + 6.0, CityBuilder.MAP_HALF - 6.0)
		car.setup(is_x, sign, road)
		car.position = Vector3(start, 0.0, road) if is_x else Vector3(road, 0.0, start)
		add_child(car)
	_spawn_traffic_lights()

func _spawn_traffic_lights() -> void:
	for rx in CityBuilder.ROADS:
		for rz in CityBuilder.ROADS:
			var pole_pos := Vector3(rx + CityBuilder.ROAD_HALF + 1.4, 0, rz + CityBuilder.ROAD_HALF + 1.4)
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.08
			pole_mesh.bottom_radius = 0.1
			pole_mesh.height = 3.0
			pole_mesh.material = Palette.flat_material(Palette.LAMP_POLE)
			pole.mesh = pole_mesh
			pole.position = Vector3(pole_pos.x, 1.5, pole_pos.z)
			add_child(pole)
			# Duas luzes: uma para cada eixo de transito.
			_add_light(pole_pos + Vector3(0, 3.2, 0), true)
			_add_light(pole_pos + Vector3(0, 2.7, 0), false)

func _add_light(at: Vector3, is_x: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	add_child(mesh_instance)
	traffic_lights.append({ "material": material, "is_x": is_x })

func _tick_traffic_lights(delta: float) -> void:
	light_timer += delta
	if light_sub == "green" and light_timer >= LIGHT_GREEN:
		light_sub = "yellow"
		light_timer = 0.0
	elif light_sub == "yellow" and light_timer >= LIGHT_YELLOW:
		light_sub = "green"
		light_timer = 0.0
		light_active_x = not light_active_x
	for light in traffic_lights:
		var is_x: bool = bool(light["is_x"])
		var material: StandardMaterial3D = light["material"]
		var col: Color
		if is_x == light_active_x:
			col = Color("#f5c542") if light_sub == "yellow" else Color("#4bd66a")
		else:
			col = Color("#e04b4b")
		material.albedo_color = col
		material.emission = col

# Verde para dirigir so no eixo ativo E na fase verde (amarelo/vermelho = parar).
func is_axis_green(is_x: bool) -> bool:
	return is_x == light_active_x and light_sub == "green"

# Pontos aleatorios sobre as ruas (para spawn de personagens).
func _street_points(count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var roads := CityBuilder.ROADS
	for _i in count:
		var on_x := randf() < 0.5
		var r: float = roads[randi() % roads.size()]
		var t := randf_range(-CityBuilder.MAP_HALF + 6.0, CityBuilder.MAP_HALF - 6.0)
		points.append(Vector3(t, 0.2, r) if on_x else Vector3(r, 0.2, t))
	return points

func _process(delta: float) -> void:
	if phase != "playing":
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		elif Input.is_action_just_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if Input.is_action_just_pressed("toggle_map") and not alarm_targeting and not route_selecting:
		_set_map_expanded(not minimap.expanded)
	_tick_traffic_lights(delta)
	_tick_robbery_yields(delta)
	_tick_suspicion(delta)
	_tick_alert()
	_update_hud()
	_check_thieves_victory()
	_check_police_victory()

func _tick_suspicion(delta: float) -> void:
	for thief in get_tree().get_nodes_in_group("thieves"):
		if thief.ability_cd_left > 0.0:
			thief.ability_cd_left = maxf(0.0, thief.ability_cd_left - delta)
		var over: int = thief.carried_money - MONEY_NERVOUS_THRESHOLD
		if over > 0:
			var mult := 1.0 + float(over) / 400.0
			if thief.ability == Abilities.SMUGGLER:
				mult *= 0.6   # contrabandista aguenta mais dinheiro antes de suar
			thief.suspicion = minf(100.0, thief.suspicion + NERVOUS_RATE * delta * mult)
		else:
			thief.suspicion = maxf(0.0, thief.suspicion - CALM_RATE * delta)

func _tick_robbery_yields(delta: float) -> void:
	for target_type: String in robbery_yield_by_type:
		var multiplier: float = robbery_yield_by_type[target_type]
		robbery_yield_by_type[target_type] = minf(1.0, multiplier + ROBBERY_YIELD_RECOVERY * delta)

func _robbery_value(target_type: String, base_value: int) -> int:
	var multiplier: float = robbery_yield_by_type.get(target_type, 1.0)
	var value := maxi(1, int(round(float(base_value) * multiplier)))
	robbery_yield_by_type[target_type] = maxf(ROBBERY_YIELD_MIN, multiplier * ROBBERY_YIELD_DECAY)
	return value

func relieve_by_disguise(thief: CharacterBase) -> void:
	thief.suspicion = maxf(0.0, thief.suspicion - CLOTHES_RELIEF)

func max_decoys_for(thief: CharacterBase) -> int:
	return MAX_DECOYS_PER_THIEF * (2 if thief.ability == Abilities.CAMOUFLAGER else 1)

func channel_time_for(thief: CharacterBase, base_time: float) -> float:
	return base_time * (0.6 if thief.ability == Abilities.THIEF_EXPERT else 1.0)

func use_ability(thief: CharacterBase) -> void:
	if not Abilities.is_active(thief.ability):
		if thief == player:
			hud.toast("SUA HABILIDADE E PASSIVA: %s" % Abilities.description(thief.ability))
		return
	if thief.ability_cd_left > 0.0:
		if thief == player:
			hud.toast("HABILIDADE RECARREGANDO (%ds)" % int(ceil(thief.ability_cd_left)))
		return
	match thief.ability:
		Abilities.HACKER:
			if thief == player:
				# Abre o mapa expandido em modo alvo: o jogador clica onde disparar.
				alarm_targeting = true
				minimap.set_targeting(true)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				hud.toast("ESCOLHA NO MAPA ONDE DISPARAR O ALARME", 3.0)
			else:
				# Bot: dispara direto num alvo aleatorio.
				thief.ability_cd_left = Abilities.cooldown(thief.ability)
				var targets := get_tree().get_nodes_in_group("robbable")
				if not targets.is_empty():
					raise_alert(targets[randi() % targets.size()].global_position)
		Abilities.INFORMANT:
			thief.ability_cd_left = Abilities.cooldown(thief.ability)
			_reveal_police(6.0)
			if thief == player:
				hud.toast("POLICIAIS REVELADOS POR 6 SEGUNDOS!")

func trigger_remote_alarm(world_pos: Vector3) -> void:
	if not alarm_targeting:
		return
	# Ancora no alvo roubavel mais proximo do clique (loja/carro/ATM), se houver.
	var anchor := world_pos
	var best := 10.0
	for target in get_tree().get_nodes_in_group("robbable"):
		var d: float = Vector2(target.global_position.x - world_pos.x, target.global_position.z - world_pos.z).length()
		if d < best:
			best = d
			anchor = target.global_position
	raise_alert(anchor)
	player.ability_cd_left = Abilities.cooldown(Abilities.HACKER)
	_end_alarm_targeting()
	hud.toast("ALARME DISPARADO NA REGIAO %s!" % region_name(anchor))

func cancel_remote_alarm() -> void:
	_end_alarm_targeting()
	hud.toast("ALARME CANCELADO")

func _end_alarm_targeting() -> void:
	alarm_targeting = false
	minimap.set_expanded(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_map_expanded(value: bool) -> void:
	minimap.set_expanded(value)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func _reveal_police(duration: float) -> void:
	for officer in get_tree().get_nodes_in_group("police"):
		var marker := officer.get_node_or_null("RevealMarker")
		if marker == null:
			marker = MeshInstance3D.new()
			marker.name = "RevealMarker"
			var mesh := SphereMesh.new()
			mesh.radius = 0.4
			mesh.height = 0.8
			var mat := Palette.flat_material(Palette.POLICE_BEACON)
			mat.emission_enabled = true
			mat.emission = Palette.POLICE_BEACON
			mesh.material = mat
			marker.mesh = mesh
			marker.position.y = 3.2
			officer.add_child(marker)
		var timer := marker.get_node_or_null("Lifetime") as Timer
		if timer == null:
			timer = Timer.new()
			timer.name = "Lifetime"
			timer.one_shot = true
			marker.add_child(timer)
			timer.timeout.connect(marker.queue_free)
		timer.start(duration)

func _tick_alert() -> void:
	if alert_until_ms > 0 and Time.get_ticks_msec() > alert_until_ms:
		alert_until_ms = 0
		hud.set_alert(false)

func alert_is_active() -> bool:
	return Time.get_ticks_msec() < alert_until_ms

func raise_alert(origin: Vector3) -> void:
	alert_origin = origin
	alert_started_ms = Time.get_ticks_msec()
	alert_until_ms = alert_started_ms + int(ALERT_DURATION * 1000.0)
	hud.set_alert(true, "ALERTA: ROUBO NA REGIAO %s!" % region_name(origin))
	audio.play("alarm") # audio
	for officer in get_tree().get_nodes_in_group("police"):
		if officer.has_method("respond_to_alert"):
			officer.respond_to_alert(origin)

func region_name(position_3d: Vector3) -> String:
	if absf(position_3d.x) < 4.5 and absf(position_3d.z) < 4.5:
		return "CENTRAL"
	if absf(position_3d.x) >= absf(position_3d.z):
		return "LESTE" if position_3d.x > 0 else "OESTE"
	return "SUL" if position_3d.z > 0 else "NORTE"

# --- Linha de visao do policial --------------------------------------------
# Um roubo so pode acontecer se NENHUM policial estiver vendo o ladrao.
# Ver = dentro do alcance + no cone de visao + sem obstaculo no caminho
# (predios, carros, props E ate outros NPCs servem de cobertura).

func seeing_officer(thief: CharacterBase) -> Node3D:
	var eye := thief.global_position + Vector3(0, 1.0, 0)
	var space := get_world_3d().direct_space_state
	for officer in get_tree().get_nodes_in_group("police"):
		if officer == thief:
			continue
		var to_thief: Vector3 = thief.global_position - officer.global_position
		to_thief.y = 0.0
		var dist := to_thief.length()
		if dist > VISION_RANGE or dist < 0.5:
			continue
		var forward: Vector3 = -officer.global_transform.basis.z
		forward.y = 0.0
		if forward.length() < 0.01:
			continue
		if forward.normalized().dot(to_thief.normalized()) < VISION_CONE_COS:
			continue
		var officer_eye: Vector3 = officer.global_position + Vector3(0, 1.4, 0)
		var query := PhysicsRayQueryParameters3D.create(officer_eye, eye)
		query.exclude = [officer.get_rid(), thief.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return officer
	return null

# Checa visao e, se visto, gera flagrante (o policial vai atras). Retorna true
# se PODE roubar (ninguem vendo).
func check_robbery_vision(thief: CharacterBase) -> bool:
	var officer := seeing_officer(thief)
	if officer == null:
		return true
	thief.suspicion = minf(100.0, thief.suspicion + 45.0)
	if officer.has_method("witness_crime"):
		officer.witness_crime(thief)
	if thief == player:
		hud.toast("UM POLICIAL ESTA TE VENDO! SAIA DA LINHA DE VISAO PARA ROUBAR", 3.0)
	return false

# --- Interacao e roubo -----------------------------------------------------

func find_interactable(thief: CharacterBase) -> Dictionary:
	var best := {}
	var best_distance := INF
	for stash in get_tree().get_nodes_in_group("stashes"):
		var distance: float = thief.global_position.distance_to(stash.global_position)
		if distance < 2.2 and distance < best_distance:
			best_distance = distance
			best = { "kind": "stash", "node": stash, "label": "RESGATAR DINHEIRO ESCONDIDO" }
	for decoy in get_tree().get_nodes_in_group("decoys"):
		var distance: float = thief.global_position.distance_to(decoy.global_position)
		if distance < 2.2 and distance < best_distance:
			best_distance = distance
			best = { "kind": "decoy", "node": decoy, "label": "REMOVER ISCA" }
	for npc in get_tree().get_nodes_in_group("civilians"):
		if not npc.can_be_robbed or npc.frozen:
			continue
		var distance: float = thief.global_position.distance_to(npc.global_position)
		if distance < 2.4 and distance < best_distance:
			best_distance = distance
			best = { "kind": "npc", "node": npc, "label": "ROUBAR NPC (R$ %d)" % NPC_ROB_VALUE }
	for target in get_tree().get_nodes_in_group("robbable"):
		if Time.get_ticks_msec() < int(target.get_meta("next_rob_at_ms")):
			continue
		var distance: float = thief.global_position.distance_to(target.global_position)
		if distance < 2.8 and distance < best_distance:
			best_distance = distance
			best = {
				"kind": "target",
				"node": target,
				"label": "ROUBAR %s (R$ %d, %.1fs)" % [String(target.get_meta("label")), int(target.get_meta("value")), float(target.get_meta("channel_time"))],
			}
	return best

func rob_npc(thief: CharacterBase, npc: Node3D) -> void:
	if phase != "playing" or not npc.can_be_robbed:
		return
	if not check_robbery_vision(thief):
		return
	npc.robbed()
	var base_value := NPC_ROB_VALUE
	if thief.ability == Abilities.PICKPOCKET:
		base_value = int(round(NPC_ROB_VALUE * 1.5))
	var value := _robbery_value("npc", base_value)
	thief.carried_money += value
	stats_stolen += value
	audio.play("robbery") # audio
	_after_rob(thief, npc.global_position)
	if thief == player:
		hud.toast("VOCE ROUBOU R$ %d" % value)

func rob_target(thief: CharacterBase, target: Node3D) -> void:
	if phase != "playing" or not is_instance_valid(target):
		return
	if Time.get_ticks_msec() < int(target.get_meta("next_rob_at_ms")):
		return
	if not check_robbery_vision(thief):
		return
	var target_type := String(target.get_meta("kind", "target"))
	var value := _robbery_value(target_type, int(target.get_meta("value")))
	target.set_meta("next_rob_at_ms", Time.get_ticks_msec() + int(float(target.get_meta("cooldown")) * 1000.0))
	thief.carried_money += value
	stats_stolen += value
	audio.play("robbery") # audio
	_after_rob(thief, target.global_position)
	if thief == player:
		hud.toast("VOCE ROUBOU R$ %d DE %s" % [value, String(target.get_meta("label"))])

func _after_rob(thief: CharacterBase, origin: Vector3) -> void:
	# Roubar NAO alivia — pelo contrario, aumenta o dinheiro carregado (e o
	# nervosismo cresce com isso, ao longo do tempo, no _tick_suspicion).
	raise_alert(origin)

# --- Camuflagem estilo prop hunt ---------------------------------------------
# O ladrao copia o MOLDE de um objeto do cenario (C), depois coloca o dinheiro
# disfarçado ONDE QUISER (Q) e espalha iscas identicas (T) para confundir.
# O objeto com dinheiro ganha um marcador $ para o dono nao esquecer.

func prop_label(prop_type: String) -> String:
	return PropLabels.of(prop_type)

func can_start_placement(thief: CharacterBase, mode: String) -> bool:
	if phase != "playing" or not thief.is_thief or thief.frozen or mode not in ["stash", "decoy", "move_decoy"]:
		return false
	if thief.copied_prop_type == "":
		if thief == player:
			hud.toast("COPIE UM MOLDE PRIMEIRO (C PERTO DE UM OBJETO)")
		return false
	if mode == "stash" and thief.carried_money <= 0:
		if thief == player:
			hud.toast("VOCE NAO ESTA CARREGANDO DINHEIRO")
		return false
	if mode == "decoy" and _decoy_count(thief) >= max_decoys_for(thief):
		if thief == player:
			hud.toast("LIMITE DE %d ISCAS — REMOVA UMA COM E" % max_decoys_for(thief))
		return false
	return true

# Placement is unrestricted by lots/overlap. The aiming ray chooses a surface;
# the manager retains finite coordinates, world limits and proper orientation.
func is_placement_position_valid(position_3d: Vector3) -> bool:
	return position_3d.is_finite() and absf(position_3d.x) <= CityBuilder.MAP_HALF and absf(position_3d.z) <= CityBuilder.MAP_HALF and position_3d.y >= -2.0 and position_3d.y <= 60.0

func can_move_decoy(thief: CharacterBase, decoy: Node3D) -> bool:
	if not is_instance_valid(decoy) or phase != "playing" or not thief.is_thief or thief.frozen:
		return false
	for record in placed_objects:
		if record["node"] == decoy and record["owner"] == thief and int(record["amount"]) == 0:
			return true
	return false

func move_decoy(thief: CharacterBase, decoy: Node3D, pose: Transform3D) -> bool:
	if not can_move_decoy(thief, decoy) or not is_placement_position_valid(pose.origin) or not PropPlacement.valid_basis(pose.basis):
		return false
	if thief.global_position.distance_to(pose.origin) > 8.0:
		return false
	decoy.global_transform = pose
	PlacementFeedback.settle(decoy)
	audio.play("hide_money")
	return true

func copy_prop(thief: CharacterBase) -> void:
	if phase != "playing":
		return
	var closest: Node3D
	var closest_distance := COPY_RANGE
	for prop in get_tree().get_nodes_in_group("camouflage_props"):
		var distance: float = thief.global_position.distance_to(prop.global_position)
		if distance < closest_distance:
			closest = prop
			closest_distance = distance
	if closest == null:
		if thief == player:
			hud.toast("APROXIME-SE DE UM OBJETO DO CENARIO PARA COPIAR O MOLDE")
		return
	thief.copied_prop_type = String(closest.get_meta("prop_type"))
	if thief == player:
		hud.toast("MOLDE COPIADO: %s" % prop_label(thief.copied_prop_type))

func hide_money(thief: CharacterBase) -> bool:
	if phase != "playing" or thief.carried_money <= 0:
		if thief == player:
			hud.toast("VOCE NAO ESTA CARREGANDO DINHEIRO")
		return false
	if thief.copied_prop_type == "":
		# Bots (e jogadores sem molde) copiam automaticamente um objeto proximo.
		var closest: Node3D
		var closest_distance := COPY_RANGE
		for prop in get_tree().get_nodes_in_group("camouflage_props"):
			var distance: float = thief.global_position.distance_to(prop.global_position)
			if distance < closest_distance:
				closest = prop
				closest_distance = distance
		if closest == null:
			if thief == player:
				hud.toast("COPIE UM MOLDE PRIMEIRO (C PERTO DE UM OBJETO)")
			return false
		thief.copied_prop_type = String(closest.get_meta("prop_type"))
	return hide_money_at(thief, _side_position(thief))

func hide_money_at(thief: CharacterBase, position_3d: Vector3, orientation: Basis = Basis.IDENTITY) -> bool:
	if not can_start_placement(thief, "stash") or not is_placement_position_valid(position_3d) or not PropPlacement.valid_basis(orientation):
		return false
	var stash := _spawn_prop_copy(thief, "Stash", position_3d, orientation)
	stash.add_to_group("stashes")
	_attach_money_marker(stash)
	placed_objects.append({
		"node": stash,
		"amount": thief.carried_money,
		"owner": thief,
		"created_ms": Time.get_ticks_msec(),
		"claimed": false,
	})
	if thief == player:
		hud.toast("R$ %d ESCONDIDO COMO %s — MARCADO COM $" % [thief.carried_money, prop_label(thief.copied_prop_type)])
	audio.play("hide_money") # audio
	thief.carried_money = 0
	return true

func place_decoy_at(thief: CharacterBase, position_3d: Vector3, orientation: Basis = Basis.IDENTITY) -> void:
	if not can_start_placement(thief, "decoy") or not is_placement_position_valid(position_3d) or not PropPlacement.valid_basis(orientation):
		return
	var decoy := _spawn_prop_copy(thief, "Decoy", position_3d, orientation)
	decoy.add_to_group("decoys")
	decoy.add_to_group("camouflage_props")
	placed_objects.append({
		"node": decoy,
		"amount": 0,
		"owner": thief,
		"created_ms": Time.get_ticks_msec(),
		"claimed": false,
	})
	if thief == player:
		hud.toast("ISCA COLOCADA (%d/%d)" % [_decoy_count(thief), max_decoys_for(thief)])
	audio.play("hide_money")

func remove_decoy(thief: CharacterBase, decoy_node: Node3D) -> void:
	for index in placed_objects.size():
		if placed_objects[index]["node"] == decoy_node and int(placed_objects[index]["amount"]) == 0:
			placed_objects.remove_at(index)
			decoy_node.queue_free()
			if thief == player:
				hud.toast("ISCA REMOVIDA (%d/%d)" % [_decoy_count(thief), max_decoys_for(thief)])
			return

func retrieve_stash(thief: CharacterBase, stash_node: Node3D) -> void:
	for index in placed_objects.size():
		if placed_objects[index]["node"] == stash_node and int(placed_objects[index]["amount"]) > 0:
			thief.carried_money += int(placed_objects[index]["amount"])
			placed_objects.remove_at(index)
			stash_node.queue_free()
			audio.play("retrieve_money") # audio
			if thief == player:
				hud.toast("DINHEIRO RESGATADO — AGORA VOCE ESTA CARREGANDO")
			return

func _side_position(thief: CharacterBase) -> Vector3:
	var side_offset: Vector3 = thief.global_transform.basis * Vector3(1.15, 0.0, 0.4)
	return Vector3(thief.global_position.x + side_offset.x, 0.0, thief.global_position.z + side_offset.z)

func _spawn_prop_copy(thief: CharacterBase, prefix: String, position_3d: Vector3, orientation: Basis = Basis.IDENTITY) -> StaticBody3D:
	var prop := CityBuilder.create_prop(thief.copied_prop_type)
	prop.name = "%s_%s" % [prefix, thief.copied_prop_type]
	prop.transform = Transform3D(orientation, position_3d)
	add_child(prop)
	PlacementFeedback.settle(prop)
	return prop

func _attach_money_marker(stash: Node3D) -> void:
	# Marcador visivel para o dono nao esquecer onde esta o dinheiro.
	# (No multiplayer este marcador devera ser visivel APENAS ao time dos ladroes.)
	var marker := Label3D.new()
	marker.name = "MoneyMarker"
	marker.text = "$"
	marker.font_size = 72
	marker.pixel_size = 0.012
	marker.modulate = Color("#f5c542")
	marker.outline_size = 14
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.position = Vector3(0, 1.7, 0)
	# Se o jogador ja virou policial, ele nao faz mais parte do time dos
	# ladroes e nao deve ver marcadores novos.
	marker.visible = player == null or player.get("team") != "police"
	stash.add_child(marker)

func _decoy_count(thief: CharacterBase) -> int:
	var count := 0
	for record in placed_objects:
		if record["owner"] == thief and int(record["amount"]) == 0 and is_instance_valid(record["node"]):
			count += 1
	return count

func claim_suspect_stash(_officer: Node3D) -> Node3D:
	# A policia nao sabe o que e isca e o que e dinheiro: inspeciona qualquer
	# objeto colocado recentemente perto da regiao do alerta.
	if not alert_is_active():
		return null
	for record in placed_objects:
		if record["claimed"]:
			continue
		var node: Node3D = record["node"]
		if not is_instance_valid(node):
			continue
		if node.global_position.distance_to(alert_origin) > STASH_SUSPECT_RADIUS:
			continue
		if int(record["created_ms"]) < alert_started_ms - STASH_RECENT_WINDOW_MS:
			continue
		record["claimed"] = true
		return node
	return null

func recover_stash(_officer: Node3D, stash_node: Node3D) -> void:
	for index in placed_objects.size():
		if placed_objects[index]["node"] == stash_node:
			var amount := int(placed_objects[index]["amount"])
			if amount > 0:
				recovered_money += amount
				placed_objects.remove_at(index)
				stash_node.queue_free()
				hud.toast("A POLICIA ENCONTROU R$ %d ESCONDIDOS!" % amount)
			else:
				# Same inspection duration and prompt for bait and real money.
				# Only the result reveals the decoy; both human and AI police break it.
				placed_objects.remove_at(index)
				PlacementFeedback.burst(self, stash_node.global_position, true)
				stash_node.queue_free()
				audio.play("frisk")
				if _officer == player:
					hud.toast("ISCA DESTRUÍDA — NENHUM DINHEIRO ENCONTRADO")
			return

# --- Abordagem, prisao e conversao -----------------------------------------

func on_approach_started(_officer: Node3D, target: CharacterBase) -> void:
	audio.play("frisk") # audio
	if target == player:
		hud.toast("VOCE FOI PARALISADO PARA REVISTA — FIQUE PARADO", 3.0)

func resolve_frisk(_officer: Node3D, target: CharacterBase) -> void:
	if not is_instance_valid(target):
		return
	if target.carried_money > 0:
		var seized := target.carried_money
		recovered_money += seized
		target.carried_money = 0
		stats_conversions += 1
		audio.play("conversion") # audio
		if target == player:
			_convert_player(seized)
			return
		hud.toast("UM LADRAO FOI PRESO E CONVERTIDO EM POLICIAL!", 3.2)
		_convert_thief(target)
	else:
		target.mark_checked(CHECKED_DURATION)
		target.suspicion = 15.0
		target.set_frozen(false)
		if target == player:
			hud.toast("REVISTA LIMPA — VOCE FOI LIBERADO COM MARCA TEMPORARIA")

func _convert_player(seized: int) -> void:
	# GDD: nao ha eliminacao permanente — o preso volta como policial.
	player.set_frozen(false)
	player.become_police()
	# O jogador trocou de lado: os marcadores $ do time dos ladroes somem.
	for record in placed_objects:
		var node: Node3D = record["node"]
		if is_instance_valid(node):
			var marker := node.get_node_or_null("MoneyMarker")
			if marker != null:
				marker.visible = false
	hud.toast("VOCE FOI PRESO COM R$ %d E CONVERTIDO EM POLICIAL — PRENDA OS LADROES!" % seized, 5.0)

func find_police_interactable(officer: CharacterBase) -> Dictionary:
	var best := {}
	var best_distance := INF
	for suspect in get_tree().get_nodes_in_group("friskable"):
		if suspect.frozen or suspect.is_checked():
			continue
		var distance: float = officer.global_position.distance_to(suspect.global_position)
		if distance < 2.3 and distance < best_distance:
			best_distance = distance
			best = { "kind": "frisk", "node": suspect, "label": "PARALISAR E REVISTAR" }
	for record in placed_objects:
		var node: Node3D = record["node"]
		if not is_instance_valid(node):
			continue
		var distance: float = officer.global_position.distance_to(node.global_position)
		if distance < 2.3 and distance < best_distance:
			best_distance = distance
			best = { "kind": "inspect", "node": node, "label": "INSPECIONAR / DESMONTAR OBJETO" }
	return best

func _convert_thief(bot: CharacterBase) -> void:
	var spawn_position := bot.global_position
	var uniform := CharacterStyle.uniform_for(bot.character_outfit)
	bot.queue_free()
	var officer := PoliceScript.new()
	officer.character_outfit = uniform
	officer.name = "ConvertedPolice_%d" % (get_tree().get_nodes_in_group("police").size() + 1)
	officer.position = spawn_position
	add_child(officer)

# --- Fim de partida ----------------------------------------------------------

func team_money() -> int:
	var total := 0
	for thief in get_tree().get_nodes_in_group("thieves"):
		total += thief.carried_money
	return total + hidden_money()

func hidden_money() -> int:
	var total := 0
	for record in placed_objects:
		total += int(record["amount"])
	return total

func _stats_summary() -> String:
	var elapsed := int((Time.get_ticks_msec() - match_start_ms) / 1000.0)
	return "Roubado no total: R$ %d | Recuperado pela policia: R$ %d | Ladroes convertidos: %d | Duracao: %d:%02d" % [
		stats_stolen, recovered_money, stats_conversions, elapsed / 60, elapsed % 60
	]

func _check_thieves_victory() -> void:
	if team_money() < MONEY_GOAL:
		return
	phase = "thieves_won"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var detail := "O time acumulou R$ %d entre dinheiro carregado e escondido, atingindo a meta de R$ %d.\n%s" % [team_money(), MONEY_GOAL, _stats_summary()]
	if player.get("team") == "police":
		audio.play("defeat") # audio
		hud.show_end("OS LADROES ATINGIRAM A META", "Voce foi convertido durante a partida e a policia nao conseguiu impedir a meta.\n" + detail)
	else:
		audio.play("victory") # audio
		hud.show_end("OS LADROES VENCERAM!", detail)

func _check_police_victory() -> void:
	if not get_tree().get_nodes_in_group("thieves").is_empty():
		return
	phase = "police_won"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var detail := "Todos os ladroes foram convertidos em policiais.\n%s" % _stats_summary()
	if player.get("team") == "police":
		audio.play("victory") # audio
		hud.show_end("A POLICIA VENCEU!", "Voce ajudou a converter os ladroes restantes.\n" + detail)
	else:
		audio.play("defeat") # audio
		hud.show_end("A POLICIA VENCEU", detail)

func set_blend_status(active: bool) -> void:
	hud.set_blend(active)

# --- HUD ---------------------------------------------------------------------

func _update_hud() -> void:
	var carried_total := 0
	for thief in get_tree().get_nodes_in_group("thieves"):
		carried_total += thief.carried_money
	hud.update_team(team_money(), MONEY_GOAL, carried_total, hidden_money())
	hud.update_counts(
		get_tree().get_nodes_in_group("thieves").size(),
		get_tree().get_nodes_in_group("police").size()
	)
	if player.get("team") == "police":
		hud.set_action_bar_mode("police")
		hud.update_police_mode(get_tree().get_nodes_in_group("thieves").size())
		var police_interactable := find_police_interactable(player)
		hud.update_action_slot("frisk", {
			"enabled": not police_interactable.is_empty() or player.is_channeling(),
			"highlight": not police_interactable.is_empty() or player.is_channeling(),
			"cd_ratio": player.channel_progress() if player.is_channeling() else 0.0,
			"cd_text": "",
			"name": "INSPEC." if player.get("police_action") == "inspect" else "REVISTAR",
		})
		if player.is_channeling():
			var action_label := "REVISTANDO SUSPEITO..."
			if player.get("police_action") != "frisk":
				action_label = "INSPECIONANDO OBJETO..."
			hud.set_channel(true, player.channel_progress(), action_label)
			hud.set_hint("")
			return
		hud.set_channel(false)
		if police_interactable.is_empty():
			hud.set_hint("")
		else:
			hud.set_hint(String(police_interactable["label"]))
		return
	hud.set_action_bar_mode("thief")
	_update_thief_action_bar()
	hud.update_pressure(player.suspicion, player.carried_money, MONEY_NERVOUS_THRESHOLD)
	var ability_text := "HABILIDADE: %s" % Abilities.display_name(player.ability)
	if Abilities.is_active(player.ability):
		if player.ability_cd_left > 0.0:
			ability_text += "  (G em %ds)" % int(ceil(player.ability_cd_left))
		else:
			ability_text += "  (G PRONTA)"
	else:
		ability_text += "  (passiva)"
	hud.update_ability(ability_text)
	if player.has_method("is_channeling") and player.is_channeling():
		hud.set_channel(true, player.channel_progress(), "ROUBANDO... NAO SE MOVA")
		hud.set_hint("")
		return
	hud.set_channel(false)
	if player.copied_prop_type == "":
		hud.update_mold("MOLDE: NENHUM (copie um objeto com C)", 0, MAX_DECOYS_PER_THIEF)
	else:
		var pocket := " (BOLSO)" if MoldLoadout.selected().has(player.copied_prop_type) else ""
		hud.update_mold("MOLDE: %s%s" % [prop_label(player.copied_prop_type), pocket], _decoy_count(player), max_decoys_for(player))
	if player.placement_active:
		hud.set_hint("COLOCANDO OBJETO...  |  MOVER, ESC OU BOTÃO DIREITO CANCELA")
		return
	if player.placement_mode != "":
		var action_text: String
		if player.placement_mode == "stash":
			action_text = "ESCONDER R$ %d (vira %s)" % [player.carried_money, prop_label(player.copied_prop_type)]
		else:
			action_text = "COLOCAR ISCA (%s)" % prop_label(player.copied_prop_type)
		hud.set_hint("CLIQUE: %s | RODA: GIRAR | SHIFT+RODA: FACE | DIREITO: CANCELAR" % ("MOVER ISCA" if player.placement_mode == "move_decoy" else action_text))
		return
	var hints: Array[String] = []
	var interactable := find_interactable(player)
	if not interactable.is_empty():
		hints.append("E  %s" % String(interactable["label"]))
	var near_prop := false
	for prop in get_tree().get_nodes_in_group("camouflage_props"):
		if player.global_position.distance_to(prop.global_position) < COPY_RANGE:
			near_prop = true
			break
	if near_prop:
		hints.append("C  COPIAR MOLDE")
	if MoldLoadout.wheel_entries(player.copied_prop_type).size() > 1:
		hints.append("DIREITO  RODA DE MOLDES")
	if player.copied_prop_type != "":
		if player.carried_money > 0:
			hints.append("Q  ESCONDER R$ %d AQUI" % player.carried_money)
		if _decoy_count(player) < max_decoys_for(player):
			hints.append("T  COLOCAR ISCA")
		hints.append("V  MOVER ISCA NA MIRA")
	hud.set_hint("   |   ".join(hints))

func _update_thief_action_bar() -> void:
	var has_mold := player.copied_prop_type != ""
	var near_prop := false
	for prop in get_tree().get_nodes_in_group("camouflage_props"):
		if player.global_position.distance_to(prop.global_position) < COPY_RANGE:
			near_prop = true
			break
	var near_civilian := false
	for npc in get_tree().get_nodes_in_group("civilians"):
		if player.global_position.distance_to(npc.global_position) < 2.3:
			near_civilian = true
			break
	var interactable := find_interactable(player)

	hud.update_action_slot("rob", {
		"enabled": not interactable.is_empty(),
		"highlight": not interactable.is_empty(),
	})
	hud.update_action_slot("copy", {
		"enabled": near_prop,
		"highlight": near_prop and not has_mold,
	})
	hud.update_action_slot("hide", {
		"enabled": has_mold and player.carried_money > 0,
		"highlight": player.placement_mode == "stash",
	})
	hud.update_action_slot("decoy", {
		"enabled": has_mold and _decoy_count(player) < max_decoys_for(player),
		"highlight": player.placement_mode == "decoy",
	})
	hud.update_action_slot("outfit", {
		"enabled": near_civilian,
		"highlight": near_civilian and not player.has_disguise,
	})
	hud.update_action_slot("route", {
		"enabled": true,
		"highlight": player.blending,
	})
	# Slot da habilidade: cooldown visual para ativas, "PASSIVA" para passivas.
	var ability_state := {
		"enabled": true,
		"highlight": false,
		"name": _ability_slot_name(player.ability),
	}
	if Abilities.is_active(player.ability):
		var cd := Abilities.cooldown(player.ability)
		if player.ability_cd_left > 0.0 and cd > 0.0:
			ability_state["cd_ratio"] = player.ability_cd_left / cd
			ability_state["cd_text"] = "%d" % int(ceil(player.ability_cd_left))
			ability_state["enabled"] = false
		else:
			ability_state["highlight"] = true
	hud.update_action_slot("ability", ability_state)

func _ability_slot_name(ability: String) -> String:
	match ability:
		Abilities.THIEF_EXPERT: return "FURTO+"
		Abilities.PICKPOCKET: return "BATEDOR"
		Abilities.SMUGGLER: return "CONTRAB."
		Abilities.CAMOUFLAGER: return "CAMUFL."
		Abilities.HACKER: return "HACKEAR"
		Abilities.INFORMANT: return "INFORM."
	return "HABIL."

func begin_route_selection() -> void:
	if phase != "playing" or player.frozen or player.team != "thief":
		return
	alarm_targeting = false
	minimap.targeting = false
	route_selecting = true
	minimap.route_targeting = true
	_set_map_expanded(true)
	hud.toast("CLIQUE NO MAPA PARA ESCOLHER SEU DESTINO", 3.0)

func cancel_route_selection() -> void:
	route_selecting = false
	minimap.route_targeting = false
	_set_map_expanded(false)

func choose_route_destination(point: Vector3) -> void:
	if not route_selecting or not point.is_finite() or phase != "playing" or player.frozen:
		return
	var waypoints := routes.path(player.global_position, point)
	cancel_route_selection()
	player.start_city_route(waypoints)
	hud.toast("INDO AO DESTINO | MOUSE GIRA A CÂMERA | WASD OU R CANCELA", 4.0)

func shift_paused_timestamps(duration_ms: int) -> void:
	match_start_ms += duration_ms
	if alert_until_ms > 0:
		alert_until_ms += duration_ms
		alert_started_ms += duration_ms
	for record in placed_objects:
		record["created_ms"] += duration_ms
	for node in find_children("*", "", true, false):
		if node.has_meta("next_rob_at_ms") and int(node.get_meta("next_rob_at_ms")) > 0:
			node.set_meta("next_rob_at_ms", int(node.get_meta("next_rob_at_ms")) + duration_ms)
		if node is CharacterBase and node.checked_until_ms > 0:
			node.checked_until_ms += duration_ms
