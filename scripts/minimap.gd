class_name Minimap
extends Control

# Mini-mapa desenhado por codigo (canto superior direito). Tecla M expande.
# No modo alvo (habilidade de alarme) o jogador clica no mapa expandido para
# disparar um alarme naquele ponto, atraindo a policia.

var game: Node3D
var expanded := false
var targeting := false
var route_targeting := false
var pulse := 0.0

const SMALL_SIZE := 210.0
const EXPANDED_SIZE := 640.0

func _ready() -> void:
	_apply_layout()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	pulse = fmod(pulse + delta * 3.0, TAU)
	queue_redraw()

func set_expanded(value: bool) -> void:
	expanded = value
	if not value:
		targeting = false
	_apply_layout()

func set_targeting(value: bool) -> void:
	targeting = value
	if value:
		expanded = true
		_apply_layout()

func _apply_layout() -> void:
	if expanded:
		set_anchors_preset(Control.PRESET_CENTER)
		var s := EXPANDED_SIZE
		offset_left = -s * 0.5
		offset_top = -s * 0.5
		offset_right = s * 0.5
		offset_bottom = s * 0.5
		# Expandido sempre bloqueia cliques (evita recapturar o mouse no jogo).
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -SMALL_SIZE - 16
		offset_top = 16
		offset_right = -16
		offset_bottom = SMALL_SIZE + 16
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _world_to_map(wx: float, wz: float) -> Vector2:
	var half := CityBuilder.MAP_HALF
	var u := (wx + half) / (half * 2.0)
	var v := (wz + half) / (half * 2.0)
	return Vector2(u * size.x, v * size.y)

func _map_to_world(pos: Vector2) -> Vector3:
	var half := CityBuilder.MAP_HALF
	var wx := pos.x / size.x * (half * 2.0) - half
	var wz := pos.y / size.y * (half * 2.0) - half
	return Vector3(wx, 0, wz)

func _gui_input(event: InputEvent) -> void:
	if route_targeting:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			if event.button_index == MOUSE_BUTTON_LEFT:
				game.choose_route_destination(_map_to_world(event.position))
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				game.cancel_route_selection()
		return
	if not targeting:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var world := _map_to_world(event.position)
			if game and game.has_method("trigger_remote_alarm"):
				game.trigger_remote_alarm(world)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if game and game.has_method("cancel_remote_alarm"):
				game.cancel_remote_alarm()

func _draw() -> void:
	if game == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.05, 0.08, 0.11, 0.9 if expanded else 0.78))
	draw_rect(rect, Color(0.4, 0.48, 0.56, 0.9), false, 2.0)

	# Ruas (grid)
	var road_col := Color(0.25, 0.29, 0.34, 0.9)
	var road_w: float = 6.0 if expanded else 3.0
	for r in CityBuilder.ROADS:
		var a := _world_to_map(-CityBuilder.MAP_HALF, r)
		var b := _world_to_map(CityBuilder.MAP_HALF, r)
		draw_line(a, b, road_col, road_w)
		var c := _world_to_map(r, -CityBuilder.MAP_HALF)
		var d := _world_to_map(r, CityBuilder.MAP_HALF)
		draw_line(c, d, road_col, road_w)

	var dot: float = 6.0 if expanded else 3.5

	# Alvos: lojas/ATM/carros (para o jogador mirar o alarme)
	for target in game.get_tree().get_nodes_in_group("robbable"):
		var kind := String(target.get_meta("kind", ""))
		var p := _world_to_map(target.global_position.x, target.global_position.z)
		var col := Color("#6fa8dc")
		if kind == "car":
			col = Color("#d0d4d8")
		elif kind == "store":
			col = Color("#f5c542")
		draw_rect(Rect2(p - Vector2(dot, dot) * 0.6, Vector2(dot, dot) * 1.2), col)

	# Dinheiro escondido do time (so aparece para ladrao)
	if game.player and game.player.get("team") != "police":
		for record in game.placed_objects:
			if int(record.get("amount", 0)) <= 0:
				continue
			var node = record.get("node")
			if node == null or not is_instance_valid(node):
				continue
			var p := _world_to_map(node.global_position.x, node.global_position.z)
			draw_circle(p, dot * 1.1, Color("#f5c542"))

	# Alerta ativo (pulsante)
	if game.alert_is_active():
		var ap := _world_to_map(game.alert_origin.x, game.alert_origin.z)
		var radius := (dot * 3.0) * (0.7 + 0.3 * sin(pulse))
		draw_arc(ap, radius, 0, TAU, 24, Color("#ff7373"), 2.5)

	# Policia (vermelho, com risco de direcao)
	for officer in game.get_tree().get_nodes_in_group("police"):
		var p := _world_to_map(officer.global_position.x, officer.global_position.z)
		draw_circle(p, dot * 1.2, Color("#e04b4b"))
		var fwd: Vector3 = -officer.global_transform.basis.z
		draw_line(p, p + Vector2(fwd.x, fwd.z).normalized() * dot * 2.5, Color("#ff9c9c"), 2.0)

	# Jogador (seta apontando na direcao)
	if game.player and is_instance_valid(game.player):
		var pp := _world_to_map(game.player.global_position.x, game.player.global_position.z)
		var fwd: Vector3 = -game.player.global_transform.basis.z
		var dir := Vector2(fwd.x, fwd.z)
		if dir.length() < 0.01:
			dir = Vector2(0, -1)
		dir = dir.normalized()
		var side := Vector2(-dir.y, dir.x)
		var tip := pp + dir * dot * 2.4
		var l := pp - dir * dot * 1.2 + side * dot * 1.4
		var r := pp - dir * dot * 1.2 - side * dot * 1.4
		draw_colored_polygon(PackedVector2Array([tip, l, r]), Color("#7ee787"))

	if game.player and game.player.blending:
		var last := _world_to_map(game.player.global_position.x, game.player.global_position.z)
		for index in range(game.player.route_index, game.player.city_route.size()):
			var point: Vector3 = game.player.city_route[index]
			var next := _world_to_map(point.x, point.z)
			draw_line(last, next, Palette.PLAYER_RING, 2.0)
			last = next
		draw_circle(last, dot * 1.5, Palette.PLAYER_RING)
	if route_targeting:
		draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 14), "CLIQUE: DESTINO NA CALÇADA | DIREITO/ESC: CANCELAR", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 16, Palette.PLAYER_RING)
	if targeting:
		var msg := "CLIQUE NUM PONTO PARA DISPARAR O ALARME  •  BOTAO DIREITO CANCELA"
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(12, size.y - 14), msg, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 16, Color("#f5d76e"))
