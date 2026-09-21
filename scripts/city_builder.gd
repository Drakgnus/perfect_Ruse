class_name CityBuilder
extends Object

# Constroi o cenario inteiro por codigo, no estilo low poly stylized:
# geometria simples, cores chapadas da Palette, sem contornos.
# Quando os packs Kenney/Quaternius forem integrados (tarefa do Codex),
# cada funcao _add_* vira ponto unico de troca por asset real.

const PROP_TYPES: Array[String] = ["barrel", "crate", "vase", "rock", "log", "cone", "bush"]

# Cidade em grid. Ruas nas linhas ROADS; quarteireis (lots) entre elas.
# --- Grade da cidade ---------------------------------------------------------
# Tudo deriva daqui. A cidade antiga era estreita demais: calcada de 2,2 m e
# quarteirao de 6,2 m de meia-largura, o que nao deixava ninguem andar pela
# calcada e fazia predio transbordar para a rua.
# 20/09/2026: era 36 m, o que dava quarteirao de 19x19 com SO 4 predios — mais
# rua do que cidade, com sensacao de vazio. Com 64 m o quarteirao fica 47x47 e
# comporta um ANEL de predios com patio interno e beco sem saida.
const ROAD_SPACING := 64.0                 # distancia entre ruas paralelas
const ROAD_HALF := 4.0                     # meia-largura do asfalto (8 m, 2 faixas)
const SIDEWALK_W := 4.5                    # largura da calcada (era 2,2)
const ROADS := [-ROAD_SPACING, 0.0, ROAD_SPACING]
const LOTS := [-1.5 * ROAD_SPACING, -0.5 * ROAD_SPACING, 0.5 * ROAD_SPACING, 1.5 * ROAD_SPACING]
const MAP_HALF := 2.0 * ROAD_SPACING
# Do centro do lote ate a borda interna da calcada.
const BLOCK_HALF := 0.5 * ROAD_SPACING - (ROAD_HALF + SIDEWALK_W)
# Centro da faixa de calcada, medido a partir do eixo da rua.
const SIDEWALK_MID := ROAD_HALF + SIDEWALK_W * 0.5
const SIDEWALK_H := 0.12   # altura da calcada; acima disso o personagem nao sobe sem rampa
# Do centro do lote ate a borda interna da calcada: 12 - (ROAD_HALF + 2.2) = 6.3.
# Nada do quarteirao pode passar disso, senao invade calcada/rua.
const CAR_WIDTH := 2.0
const CAR_LENGTH := 4.2
const PARK_LANE_OFFSET := ROAD_HALF + 1.2

# --- Anel de predios do quarteirao -------------------------------------------
# A fachada tem 8,4 m de largura por 8,0 m de profundidade (ver
# _add_neighborhood_building). O passo do anel e a fachada mais um respiro.
const RING_STEP := 9.4
const RING_DEPTH := 4.0                    # metade da profundidade do predio
const COURTYARD_HALF := BLOCK_HALF - RING_STEP   # do centro ate os fundos do anel

static func build(root: Node3D) -> void:
	_add_environment(root)
	_add_ground_and_roads(root)
	_add_buildings_and_targets(root)
	_add_city_limits(root)
	_add_cars(root)
	_add_street_furniture(root)
	_add_camouflage_props(root)

static func _add_environment(root: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Palette.SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Palette.AMBIENT
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.ssao_enabled = true
	world_environment.environment = environment
	root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.light_color = Color("#fff3e0")
	root.add_child(sun)

static func _surface(root: Node3D, label: String, at: Vector3, size: Vector3, color: Color) -> void:
	var tile := add_box(root, label, at, size, color)
	# One continuous physical ground prevents tiny road/curb edges from
	# trapping walkers. Paint and pavement are shallow visual surfaces.
	tile.collision_layer = 0
	tile.collision_mask = 0

static func _add_ground_and_roads(root: Node3D) -> void:
	var full := MAP_HALF * 2.0
	add_box(root, "Ground", Vector3(0, -0.25, 0), Vector3(full, 0.5, full), Palette.GROUND)
	var spans: Array[Vector2] = []
	var edge := -MAP_HALF
	for road in ROADS:
		spans.append(Vector2(edge, road - ROAD_HALF))
		edge = road + ROAD_HALF
	spans.append(Vector2(edge, MAP_HALF))
	for r in ROADS:
		_surface(root, "RoadX", Vector3(0, 0.004, r), Vector3(full, 0.006, ROAD_HALF * 2), Palette.ASPHALT)
		_surface(root, "RoadZ", Vector3(r, 0.005, 0), Vector3(ROAD_HALF * 2, 0.006, full), Palette.ASPHALT)
		for side in [-1.0, 1.0]:
			for span in spans:
				var mid: float = (span[0] + span[1]) * 0.5
				var length: float = span[1] - span[0]
				_add_sidewalk_span(root, span, r + side * SIDEWALK_MID, true)
				_add_sidewalk_span(root, span, r + side * SIDEWALK_MID, false)
				_surface(root, "CurbX", Vector3(mid, SIDEWALK_H * 0.5, r + side * ROAD_HALF), Vector3(length, SIDEWALK_H, 0.18), Palette.CURB)
				_surface(root, "CurbZ", Vector3(r + side * ROAD_HALF, SIDEWALK_H * 0.5, mid), Vector3(0.18, SIDEWALK_H, length), Palette.CURB)
		for i in range(-int(MAP_HALF / 5.4), int(MAP_HALF / 5.4) + 1):
			var t := i * 5.4
			if absf(t) > MAP_HALF - 2:
				continue
			_surface(root, "PaintX", Vector3(t, 0.012, r), Vector3(1.6, 0.006, 0.16), Palette.ROAD_PAINT)
			_surface(root, "PaintZ", Vector3(r, 0.014, t), Vector3(0.16, 0.006, 1.6), Palette.ROAD_PAINT)
	# Crossings match the pedestrian graph at every intersection.
	for rx in ROADS:
		for rz in ROADS:
			for side in [-1.0, 1.0]:
				for stripe in int(ROAD_HALF * 2):
					var t := -ROAD_HALF + 0.5 + stripe
					_surface(root, "CrosswalkX", Vector3(rx + t, 0.018, rz + side * CityRoutes.WALK_OFFSET), Vector3(0.55, 0.006, 1.2), Palette.ROAD_PAINT)
					_surface(root, "CrosswalkZ", Vector3(rx + side * CityRoutes.WALK_OFFSET, 0.019, rz + t), Vector3(1.2, 0.006, 0.55), Palette.ROAD_PAINT)
	for side in [-1.0, 1.0]:
		_surface(root, "PerimeterWalkX", Vector3(0, 0.013, side * (MAP_HALF - 2.5)), Vector3(full, 0.02, 1.8), Palette.SIDEWALK)
		_surface(root, "PerimeterWalkZ", Vector3(side * (MAP_HALF - 2.5), 0.013, 0), Vector3(1.8, 0.02, full), Palette.SIDEWALK)

static func _add_buildings_and_targets(root: Node3D) -> void:
	var shop_index := 0
	var atm_count := 0
	var index := 0
	for lx in LOTS:
		for lz in LOTS:
			var base := Vector3(lx, 0, lz)
			var face := _road_facing_offset(base)
			var kind := _lot_kind(base)
			if kind != "block":
				_add_open_lot(root, base, kind)
			else:
				shop_index = _add_city_block(root, base, face, index, shop_index)
				if atm_count < 6 and index % 2 == 1:
					# Deslocado um predio para o lado: a loja fica no centro
					# dessa face e os dois destinos nao podem coincidir (dois
					# pontos de rota no mesmo lugar duplicavam spawn de civil).
					var right := Vector3(face.z, 0, -face.x)
					_add_atm(root, base + face * (BLOCK_HALF + 3.0) + right * RING_STEP)
					atm_count += 1
			index += 1

# Posicoes ao longo de um lado do anel, centradas e simetricas. Derivado de
# RING_STEP para a quadra continuar coerente se a escala mudar de novo.
static func _ring_offsets(span_half: float) -> Array:
	var count := int(floor(span_half * 2.0 / RING_STEP))
	var out: Array[float] = []
	if count <= 0:
		return out
	var start := -RING_STEP * float(count - 1) * 0.5
	for i in count:
		out.append(start + RING_STEP * float(i))
	return out

# Quarteirao fechado: anel de predios de frente para a rua, patio interno e um
# unico beco sem saida. Devolve o shop_index atualizado.
static func _add_city_block(root: Node3D, base: Vector3, face: Vector3, index: int, shop_index: int) -> int:
	_surface(root, "BlockPaving", base + Vector3(0, 0.025, 0), Vector3(BLOCK_HALF * 2.0, 0.04, BLOCK_HALF * 2.0), Palette.SIDEWALK)
	var dirs := [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]
	var alley_dir: Vector3 = dirs[index % dirs.size()]
	# O beco nunca fica na frente principal: e la que moram loja e ATM.
	if alley_dir.is_equal_approx(face):
		alley_dir = dirs[(index + 1) % dirs.size()]
	var slot := 0
	for dir in dirs:
		# Lados ao longo de Z levam a fila inteira; os perpendiculares perdem as
		# pontas, senao os predios de esquina se atravessam.
		var long_side: bool = absf(dir.z) > 0.5
		var right := Vector3(dir.z, 0, -dir.x)
		for off in _ring_offsets(BLOCK_HALF if long_side else BLOCK_HALF - RING_STEP):
			if dir.is_equal_approx(alley_dir) and absf(off) < 0.01:
				continue   # vao de entrada do beco
			var spot: Vector3 = base + dir * (BLOCK_HALF - RING_DEPTH) + right * off
			var floors := 2 + (index + slot) % 4
			if absf(base.x) <= ROAD_SPACING * 0.5 and absf(base.z) <= ROAD_SPACING * 0.5:
				floors += 2
			var shop := -1
			if dir.is_equal_approx(face) and absf(off) < 0.01 and shop_index < 6:
				shop = shop_index
				shop_index += 1
			_add_neighborhood_building(root, spot, atan2(dir.x, dir.z), floors, index + slot, shop)
			slot += 1
	_add_block_courtyard(root, base, alley_dir, index)
	return shop_index

# Miolo do quarteirao: patio cercado pelo anel, alcancavel so pelo beco.
static func _add_block_courtyard(root: Node3D, base: Vector3, alley_dir: Vector3, index: int) -> void:
	_surface(root, "Courtyard", base + Vector3(0, 0.026, 0), Vector3(COURTYARD_HALF * 2.0, 0.04, COURTYARD_HALF * 2.0), Palette.ASPHALT)
	var alley_size := Vector3(RING_STEP - 1.0, 0.04, RING_STEP) if absf(alley_dir.z) > 0.5 else Vector3(RING_STEP, 0.04, RING_STEP - 1.0)
	_surface(root, "Alley", base + alley_dir * (BLOCK_HALF - RING_STEP * 0.5) + Vector3(0, 0.026, 0), alley_size, Palette.ASPHALT)
	# Entulho do patio: mesma fabrica dos props do cenario, entao serve de
	# esconderijo de verdade. Fica fora do eixo do beco para nao tampar a entrada.
	var across := Vector3(absf(alley_dir.z), 0, absf(alley_dir.x))
	for i in 4:
		var prop := create_prop(PROP_TYPES[(index + i) % PROP_TYPES.size()])
		var along := (COURTYARD_HALF - 2.5) * (-1.0 if i % 2 == 0 else 1.0) * (0.45 if i < 2 else 0.85)
		var deep := (COURTYARD_HALF - 2.5) * (-1.0 if i < 2 else 1.0) * 0.6
		prop.position = base + across * along - alley_dir * deep
		prop.add_to_group("camouflage_props")
		root.add_child(prop)

# --- Limite da cidade --------------------------------------------------------
# A partida acontece so dentro do dominio. O fechamento e natural: fileira de
# predios de fundo em volta e barricada onde a rua encostaria na borda. Atras
# de tudo corre uma parede invisivel, para nenhum vao virar saida.
const LIMIT_DEPTH := 8.0
const BACKDROP_STEP := 11.0

static func _add_city_limits(root: Node3D) -> void:
	var line := MAP_HALF + LIMIT_DEPTH * 0.5
	for dir in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var right := Vector3(dir.z, 0, -dir.x)
		# Chao sob a fileira: o terreno base termina em MAP_HALF.
		_surface(root, "LimitGround", dir * line, Vector3(LIMIT_DEPTH, 0.02, MAP_HALF * 2.0 + LIMIT_DEPTH) if absf(dir.x) > 0.5 else Vector3(MAP_HALF * 2.0 + LIMIT_DEPTH, 0.02, LIMIT_DEPTH), Palette.PLANTER)
		var slots := int(MAP_HALF * 2.0 / BACKDROP_STEP)
		for i in slots:
			var off := -MAP_HALF + BACKDROP_STEP * (float(i) + 0.5)
			var blocked := false
			for r in ROADS:
				# 4,8 m e a meia-largura do predio de fundo: com menos que isso
				# o volume entra na faixa da rua (city_regression cobre isso).
				if absf(off - r) < ROAD_HALF + 6.0:
					blocked = true   # aqui a rua bate na borda: vai barricada
			if blocked:
				continue
			_add_backdrop_building(root, dir * line + right * off, atan2(-dir.x, -dir.z), 2 + i % 4)
		for r in ROADS:
			# Depois da calcada do perimetro (MAP_HALF - 2.5, 1,8 m de largura),
			# senao a barricada tampa o caminho dos pedestres na borda.
			_add_road_barricade(root, dir * (MAP_HALF - 0.5) + right * r, absf(dir.x) > 0.5)
		# Parede invisivel atras da fileira.
		var wall_size := Vector3(0.8, 6.0, MAP_HALF * 2.0 + LIMIT_DEPTH * 2.0) if absf(dir.x) > 0.5 else Vector3(MAP_HALF * 2.0 + LIMIT_DEPTH * 2.0, 6.0, 0.8)
		var wall := add_box(root, "CityLimitWall", dir * (MAP_HALF + LIMIT_DEPTH) + Vector3(0, 3.0, 0), wall_size, Palette.CURB)
		wall.collision_layer = 1 | 4
		for child in wall.get_children():
			if child is MeshInstance3D:
				child.visible = false

# Predio de fundo: volume + cornija + faixas de janela em UMA malha por cor.
# Detalhe cheio (_add_neighborhood_building) so nas quadras jogaveis; aqui
# seriam ~90 fachadas e o FPS cairia sem ninguem chegar perto.
static func _add_backdrop_building(root: Node3D, pos: Vector3, yaw: float, floors: int) -> void:
	var colors := [Palette.BUILDING_A, Palette.BUILDING_B, Palette.BUILDING_C, Palette.BUILDING_D]
	var height := float(floors) * 3.2
	var body := add_box(root, "BackdropBuilding", pos + Vector3(0, height * 0.5, 0), Vector3(9.6, height, LIMIT_DEPTH), colors[floors % colors.size()])
	body.rotation.y = yaw
	# Grupo proprio: "city_buildings" significa predio jogavel, com porta e
	# fachada completa, e os testes cobram isso de cada membro do grupo.
	body.add_to_group("backdrop_buildings")
	body.collision_layer = 1 | 4
	var facade := Node3D.new()
	facade.position.y = -height * 0.5
	body.add_child(facade)
	_detail(facade, "RoofCornice", Vector3(0, height, 0), Vector3(9.9, 0.3, LIMIT_DEPTH + 0.3), Palette.AMBIENT)
	for level in floors:
		_detail(facade, "WindowBand", Vector3(0, level * 3.2 + 1.7, LIMIT_DEPTH * 0.5 + 0.05), Vector3(7.6, 1.5, 0.1), Palette.SIGN)
	_batch_facade(facade)

# Barricada na boca da rua: blocos de concreto, faixas e cones.
static func _add_road_barricade(root: Node3D, pos: Vector3, along_x: bool) -> void:
	var span := ROAD_HALF * 2.0 + SIDEWALK_W * 2.0
	var size := Vector3(1.0, 1.2, span) if along_x else Vector3(span, 1.2, 1.0)
	var barrier := add_box(root, "Barricade", pos + Vector3(0, 0.6, 0), size, Palette.CURB)
	barrier.collision_layer = 1 | 4
	# As pedras ficam do lado de FORA da barricada: por dentro passa a calcada
	# do perimetro, e qualquer volume ali trava a rota dos pedestres.
	var outward := signf(pos.x if along_x else pos.z)
	for i in 5:
		var t := -span * 0.5 + span * (float(i) + 0.5) / 5.0
		_detail(root, "BarricadeStripe", pos + (Vector3(0, 1.25, t) if along_x else Vector3(t, 1.25, 0)), Vector3(1.1, 0.5, 1.1), Palette.ROAD_PAINT)
		if i % 2 == 0:
			var rock := create_prop("rock")
			rock.position = pos + (Vector3(2.2 * outward, 0, t) if along_x else Vector3(t, 0, 2.2 * outward))
			rock.scale = Vector3(1.6, 1.6, 1.6)
			root.add_child(rock)

# One architectural metre is one gameplay metre. Never shrink doors to fit lots.
static func _detail(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Palette.flat_material(color)
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
	return instance

static func _add_neighborhood_building(root: Node3D, pos: Vector3, yaw: float, floors: int, variant: int, shop: int) -> void:
	var colors := [Palette.BUILDING_A, Palette.BUILDING_B, Palette.BUILDING_C, Palette.BUILDING_D, Palette.AMBIENT]
	var height := float(floors) * 3.2
	var body := add_box(root, "UrbanBuilding", pos + Vector3(0, height / 2.0, 0), Vector3(8.4, height, 8.0), colors[variant % colors.size()])
	body.rotation.y = yaw
	body.add_to_group("city_buildings")
	body.collision_layer = 1 | 4
	var facade := Node3D.new()
	facade.position.y = -height / 2.0
	body.add_child(facade)
	body.set_meta("door_height", 2.5)
	body.set_meta("floor_height", 3.2)
	_detail(facade, "Foundation", Vector3(0, 0.22, 0), Vector3(8.5, 0.44, 8.1), Palette.CURB)
	_detail(facade, "RoofCornice", Vector3(0, height, 0), Vector3(8.7, 0.26, 8.3), Palette.AMBIENT)
	_detail(facade, "RoofInset", Vector3(0, height + 0.12, 0), Vector3(8.1, 0.14, 7.7), Palette.ROOF)
	if floors == 2 and shop < 0:
		var roof := MeshInstance3D.new()
		var roof_mesh := PrismMesh.new()
		roof_mesh.size = Vector3(8.8, 2.0, 8.4)
		roof_mesh.material = Palette.flat_material(Palette.ROOF)
		roof.mesh = roof_mesh
		roof.position.y = height + 1.0
		facade.add_child(roof)
		_detail(facade, "Chimney", Vector3(2.3, height + 1.4, -1.8), Vector3(0.7, 2.2, 0.8), Palette.BUILDING_B)
	else:
		_detail(facade, "RoofAccess", Vector3(-2, height + 0.65, -2), Vector3(1.8, 1.2, 1.8), Palette.CURB)
	for side in 4:
		var wall := Node3D.new()
		wall.rotation.y = side * PI / 2.0
		facade.add_child(wall)
		var front := 4.06 if side % 2 == 0 else 4.26
		for level in floors:
			_detail(wall, "FloorBand", Vector3(0, level * 3.2 + 0.12, front), Vector3(8.35 if side % 2 == 0 else 7.95, 0.16, 0.12), Palette.AMBIENT)
			for x in [-2.65, 0.0, 2.65]:
				if level == 0 and side == 0:
					continue
				var y: float = level * 3.2 + 1.65
				_detail(wall, "WindowFrame", Vector3(x, y, front), Vector3(1.7, 1.95, 0.14), Palette.AMBIENT)
				_detail(wall, "WindowGlass", Vector3(x, y, front + 0.085), Vector3(1.42, 1.67, 0.05), Palette.SIGN)
				_detail(wall, "WindowReflection", Vector3(x - 0.36, y, front + 0.12), Vector3(0.12, 1.5, 0.025), Palette.ATM_BODY)
				_detail(wall, "WindowSill", Vector3(x, y - 1.0, front + 0.12), Vector3(1.9, 0.14, 0.32), Palette.CURB)
				if level > 0 and side == 0 and variant % 3 == 0:
					_detail(wall, "Balcony", Vector3(x, y - 1.0, front + 0.25), Vector3(2.1, 0.14, 0.65), Palette.CURB)
					_detail(wall, "BalconyRail", Vector3(x, y - 0.35, front + 0.52), Vector3(2.1, 0.08, 0.07), Palette.LAMP_POLE)
					for rail in [-0.95, -0.48, 0.0, 0.48, 0.95]:
						_detail(wall, "Baluster", Vector3(x + rail, y - 0.67, front + 0.52), Vector3(0.055, 0.66, 0.055), Palette.LAMP_POLE)
	_detail(facade, "DoorFrame", Vector3(0, 1.35, 4.09), Vector3(1.8, 2.7, 0.2), Palette.AMBIENT)
	_detail(facade, "Door", Vector3(0, 1.25, 4.22), Vector3(1.5, 2.5, 0.07), Palette.SIGN)
	_detail(facade, "DoorGlass", Vector3(0, 1.55, 4.27), Vector3(1.15, 1.45, 0.025), Palette.ATM_BODY)
	_detail(facade, "Handle", Vector3(0.5, 1.1, 4.3), Vector3(0.07, 0.35, 0.09), Palette.ROAD_PAINT)
	var names := ["PADARIA", "MERCADO", "CAFE CENTRAL", "FARMACIA", "LIVRARIA", "BOUTIQUE"]
	var accent: Color = Palette.AWNING if variant % 2 == 0 else Palette.AWNING_ALT
	for x in [-2.65, 2.65]:
		_detail(facade, "DisplayFrame", Vector3(x, 1.5, 4.1), Vector3(2.35, 2.1, 0.2), Palette.AMBIENT)
		_detail(facade, "DisplayGlass", Vector3(x, 1.5, 4.22), Vector3(2.08, 1.85, 0.06), Palette.ATM_BODY if shop >= 0 else Palette.SIGN)
		if shop >= 0:
			_detail(facade, "DisplayShelf", Vector3(x, 0.85, 4.32), Vector3(2.0, 0.12, 0.15), Palette.BENCH)
			for item in 4:
				_detail(facade, "DisplayGoods", Vector3(x - 0.72 + item * 0.48, 1.1, 4.32), Vector3(0.3, 0.3 + 0.12 * (item % 2), 0.15), colors[(item + shop) % colors.size()])
	if shop >= 0:
		_detail(facade, "ShopSign", Vector3(0, 3.02, 4.23), Vector3(7.8, 0.68, 0.2), accent)
		var label := Label3D.new()
		label.text = names[shop]
		label.font_size = 64
		label.pixel_size = 0.007
		label.position = Vector3(0, 3.04, 4.36)
		facade.add_child(label)
		for stripe in 16:
			_detail(facade, "AwningStripe", Vector3(-3.75 + stripe * 0.5, 2.68, 4.52), Vector3(0.5, 0.14, 0.95), accent if stripe % 2 == 0 else Palette.AMBIENT)
		var target := Node3D.new()
		target.name = "ShopInteraction"
		target.position = Vector3(0, 0, 5.55)
		facade.add_child(target)
		target.add_to_group("robbable")
		for pair in [["robbable", true], ["kind", "store"], ["label", names[shop]], ["value", 450], ["channel_time", 7.0], ["cooldown", 40.0], ["next_rob_at_ms", 0]]:
			target.set_meta(pair[0], pair[1])
	else:
		_detail(facade, "EntryCanopy", Vector3(0, 2.8, 4.43), Vector3(2.4, 0.16, 0.8), accent)
		for x in [-3.5, 3.5]:
			_detail(facade, "Planter", Vector3(x, 0.3, 4.38), Vector3(0.6, 0.6, 0.55), Palette.PROP_CRATE)
			_detail(facade, "Hedge", Vector3(x, 0.75, 4.38), Vector3(0.68, 0.5, 0.6), Palette.PROP_BUSH)
	_batch_facade(facade)

# Static trim shares one mesh per color, avoiding thousands of draw calls.
static func _batch_facade(facade: Node3D) -> void:
	var batches := {}
	for node in facade.find_children("*", "MeshInstance3D", true, false):
		if node.name == "Door":
			continue
		var material: Material = node.mesh.surface_get_material(0)
		var key: Color = material.albedo_color
		if not batches.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(material)
			batches[key] = tool
		var transform: Transform3D = facade.global_transform.affine_inverse() * node.global_transform
		batches[key].append_from(node.mesh, 0, transform)
		node.free()
	for tool in batches.values():
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = tool.commit()
		facade.add_child(mesh_instance)

# Direcao (unitaria em X ou Z) da rua mais proxima ao lote.
static func _road_facing_offset(base: Vector3) -> Vector3:
	var best_axis := Vector3.FORWARD
	var best_dist := INF
	for r in ROADS:
		if absf(base.z - r) < best_dist:
			best_dist = absf(base.z - r)
			best_axis = Vector3(0, 0, signf(r - base.z) if r != base.z else 1.0)
		if absf(base.x - r) < best_dist:
			best_dist = absf(base.x - r)
			best_axis = Vector3(signf(r - base.x) if r != base.x else 1.0, 0, 0)
	return best_axis

# Escolhe o predio pelo anel do quarteirao: centro recebe torre/comercio,
# periferia recebe casa. Antes eram 4 modelos fixos ciclados, e a cidade
# inteira ficava igual.
# --- Areas abertas: praca e bosque -------------------------------------------
const PLAZA_LOT := Vector2(0.5 * ROAD_SPACING, -0.5 * ROAD_SPACING)
const PARK_LOT := Vector2(-1.5 * ROAD_SPACING, -1.5 * ROAD_SPACING)

static func _lot_kind(base: Vector3) -> String:
	if is_equal_approx(base.x, PLAZA_LOT.x) and is_equal_approx(base.z, PLAZA_LOT.y):
		return "plaza"
	if is_equal_approx(base.x, PARK_LOT.x) and is_equal_approx(base.z, PARK_LOT.y):
		return "park"
	return "block"

static func _add_open_lot(root: Node3D, base: Vector3, kind: String) -> void:
	if kind == "plaza":
		add_box(root, "PlazaFloor", base + Vector3(0, SIDEWALK_H * 0.5, 0), Vector3(BLOCK_HALF * 2.0, SIDEWALK_H, BLOCK_HALF * 2.0), Palette.SIDEWALK)
		add_box(root, "PlazaFountain", base + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 3.2), Palette.CURB)
		add_box(root, "PlazaWater", base + Vector3(0, 0.93, 0), Vector3(2.6, 0.12, 2.6), Palette.ATM_SCREEN)
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI * 0.25
			var off := Vector3(cos(a), 0, sin(a)) * 5.4
			add_box(root, "PlazaBench", base + off + Vector3(0, 0.45, 0), Vector3(2.0, 0.25, 0.7), Palette.BENCH)
		_scatter_models(root, base, ModelLibrary.PARK_TREES, 6, BLOCK_HALF - 0.9, 4.2, 2.6, 3.4)
		_scatter_models(root, base, ModelLibrary.STREET_LIGHTS, 4, BLOCK_HALF - 0.7, 4.8, 2.8, 3.2)
	else:
		add_box(root, "ParkGrass", base + Vector3(0, SIDEWALK_H * 0.5, 0), Vector3(BLOCK_HALF * 2.0, SIDEWALK_H, BLOCK_HALF * 2.0), Palette.PLANTER)
		add_box(root, "ParkPathX", base + Vector3(0, SIDEWALK_H + 0.02, 0), Vector3(BLOCK_HALF * 2.0, 0.04, 2.0), Palette.SIDEWALK)
		add_box(root, "ParkPathZ", base + Vector3(0, SIDEWALK_H + 0.02, 0), Vector3(2.0, 0.04, BLOCK_HALF * 2.0), Palette.SIDEWALK)
		_scatter_models(root, base, ModelLibrary.PARK_TREES, 14, BLOCK_HALF - 0.8, 1.8, 2.4, 4.2)

static func _scatter_models(root: Node3D, center: Vector3, pool: Array, count: int, radius: float, keep_clear: float, size_min: float, size_max: float) -> void:
	if pool.is_empty():
		return
	for i in count:
		var a := randf() * TAU
		var d := randf_range(keep_clear, radius)
		var spot := center + Vector3(cos(a), 0, sin(a)) * d
		# nao planta em cima do caminho central em cruz
		if absf(spot.x - center.x) < 1.4 or absf(spot.z - center.z) < 1.4:
			continue
		var path: String = pool[randi() % pool.size()]
		if not ResourceLoader.exists(path):
			continue
		var model := ModelLibrary.instance_fitted(path, randf_range(size_min, size_max))
		if model == null:
			continue
		var body := StaticBody3D.new()
		body.name = "LotProp"
		body.position = spot + Vector3(0, SIDEWALK_H, 0)
		body.collision_layer = 1 | 4
		body.rotation.y = randf() * TAU
		body.add_child(model)
		var size: Vector3 = model.get_meta("fitted_size", Vector3(1, 2, 1))
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(0.7, size.x * 0.45), maxf(1.2, size.y), maxf(0.7, size.z * 0.45))
		collision.shape = shape
		collision.position.y = size.y * 0.5
		body.add_child(collision)
		root.add_child(body)

static func _add_atm(root: Node3D, front_center: Vector3) -> void:
	var atm := add_box(root, "Atm", front_center + Vector3(0, 0.9, -0.1), Vector3(0.9, 1.8, 0.6), Palette.ATM_BODY)
	add_box(root, "AtmScreen", front_center + Vector3(0, 1.25, 0.22), Vector3(0.6, 0.45, 0.1), Palette.ATM_SCREEN)
	var atm_label := Label3D.new()
	atm_label.text = "ATM"
	atm_label.font_size = 64
	atm_label.pixel_size = 0.01
	atm_label.modulate = Color("#f5f1e6")
	atm_label.position = front_center + Vector3(0, 1.95, 0.15)
	root.add_child(atm_label)
	atm.set_meta("robbable", true)
	atm.set_meta("kind", "atm")
	atm.set_meta("label", "CAIXA ELETRONICO")
	atm.set_meta("value", 250)
	atm.set_meta("channel_time", 4.0)
	atm.set_meta("cooldown", 28.0)
	atm.set_meta("next_rob_at_ms", 0)
	atm.add_to_group("robbable")

# Carros estacionados nas laterais das ruas — alvo de valor/tempo medio.
static func _add_cars(root: Node3D) -> void:
	var slots_t := [-0.733 * MAP_HALF, -0.333 * MAP_HALF, 0.333 * MAP_HALF, 0.733 * MAP_HALF]
	var car_i := 0
	for r in ROADS:
		for t in slots_t:
			# Mantem o footprint de 2,0 m inteiramente no asfalto. O offset
			# anterior (ROAD_HALF + 1.3) invadia a borda dos quarteiroes.
			var side: float = 1.0 if car_i % 2 == 0 else -1.0
			var park := PARK_LANE_OFFSET
			# Carro deitado ao longo do eixo X da rua horizontal (z=r)
			_add_car(root, Vector3(t, 0, r + side * park), 90.0)
			car_i += 1
			# Carro ao longo do eixo Z da rua vertical (x=r)
			_add_car(root, Vector3(r + side * park, 0, t), 0.0)
			car_i += 1

static func _add_car(root: Node3D, position_3d: Vector3, yaw: float) -> void:
	# A visible asphalt bay separates parking from the live traffic lanes.
	var bay_size := Vector3(5.4, 0.025, 2.2) if absf(sin(deg_to_rad(yaw))) > 0.5 else Vector3(2.2, 0.025, 5.4)
	_surface(root, "ParkingBay", position_3d + Vector3(0, SIDEWALK_H + 0.018, 0), bay_size, Palette.ASPHALT)
	var body := StaticBody3D.new()
	body.name = "Car"
	body.add_to_group("road_vehicles")
	body.add_to_group("parked_cars")
	body.position = position_3d + Vector3(0, SIDEWALK_H, 0)
	body.rotation_degrees.y = yaw
	var size := Vector3(CAR_WIDTH, 1.2, CAR_LENGTH)
	if ModelLibrary.has_cars():
		# Ajusta pelo COMPRIMENTO (maior dimensao) ~4.2m; altura sai proporcional (~1.5m).
		var model := ModelLibrary.instance_fitted(ModelLibrary.random_car_model(), 4.2, true)
		if model != null:
			body.add_child(model)
			size = CityBuilder.fit_car_width(model)
	if body.get_child_count() == 0:
		# fallback primitivo
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.9, 1.1, 4.0)
		mesh.material = Palette.flat_material(Palette.random_civilian_color())
		mesh_instance.mesh = mesh
		mesh_instance.position.y = 0.7
		body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(1.6, size.x), maxf(1.0, size.y), maxf(3.0, size.z))
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	body.set_meta("robbable", true)
	body.set_meta("kind", "car")
	body.set_meta("label", "CARRO")
	body.set_meta("value", 180)
	body.set_meta("channel_time", 3.5)
	body.set_meta("cooldown", 30.0)
	body.set_meta("next_rob_at_ms", 0)
	body.add_to_group("robbable")
	root.add_child(body)

static func _car_footprint_is_on_road(position_3d: Vector3, yaw: float) -> bool:
	# Com yaw 90, o comprimento segue X e a largura limita Z; com yaw 0 e
	# equivalente, ocorre o inverso. Basta a largura caber na faixa da rua.
	var is_horizontal := absf(sin(deg_to_rad(yaw))) > 0.5
	var perpendicular := position_3d.z if is_horizontal else position_3d.x
	var nearest_road_distance := INF
	for road in ROADS:
		nearest_road_distance = minf(nearest_road_distance, absf(perpendicular - road))
	return nearest_road_distance + CAR_WIDTH * 0.5 <= ROAD_HALF

static func _add_street_furniture(root: Node3D) -> void:
	# Postes de luz nas esquinas (cruzamentos das ruas).
	for rx in ROADS:
		for rz in ROADS:
			for corner in [Vector3(ROAD_HALF + 1.0, 0, ROAD_HALF + 1.0), Vector3(-ROAD_HALF - 1.0, 0, -ROAD_HALF - 1.0)]:
				var lamp_pos := Vector3(rx + corner.x, 0, rz + corner.z)
				var pole := MeshInstance3D.new()
				var pole_mesh := CylinderMesh.new()
				pole_mesh.top_radius = 0.07
				pole_mesh.bottom_radius = 0.1
				pole_mesh.height = 3.4
				pole_mesh.material = Palette.flat_material(Palette.LAMP_POLE)
				pole.mesh = pole_mesh
				pole.position = Vector3(lamp_pos.x, 1.7, lamp_pos.z)
				root.add_child(pole)
				add_box(root, "LampHead", Vector3(lamp_pos.x, 3.4, lamp_pos.z), Vector3(0.5, 0.2, 0.5), Palette.ROAD_PAINT)

# Espacamento dos moldes ao longo da calcada. Eram 4 posicoes fixas por rua,
# pensadas para o mapa de 144 m; na cidade de 256 m o jogador andava quarteiroes
# inteiros sem achar objeto para copiar.
const PROP_SPACING := 13.0

static func _add_camouflage_props(root: Node3D) -> void:
	# Furniture uses the inner sidewalk strip between the parking bays.
	# The outside strip remains continuous for pedestrians.
	var type_i := 0
	var lane := ROAD_HALF + 0.65
	var steps := int((MAP_HALF * 2.0 - 12.0) / PROP_SPACING)
	for road in ROADS:
		for i in steps + 1:
			var t := -MAP_HALF + 6.0 + PROP_SPACING * float(i)
			# Cruzamento fica livre: e onde passam faixa, rampa e curva do carro.
			var at_crossing := false
			for other in ROADS:
				if absf(t - other) < ROAD_HALF + SIDEWALK_W + 2.0:
					at_crossing = true
			if at_crossing:
				continue
			# A vaga (PARK_LANE_OFFSET = 5,2) quase encosta nesta faixa: sem este
			# desvio o molde nasce dentro do carro estacionado.
			var at_parking := false
			for slot in [-0.733 * MAP_HALF, -0.333 * MAP_HALF, 0.333 * MAP_HALF, 0.733 * MAP_HALF]:
				if absf(t - slot) < CAR_LENGTH * 0.5 + 1.5:
					at_parking = true
			if at_parking:
				continue
			for along_x in [true, false]:
				for side in [-1.0, 1.0]:
					var prop := create_prop(PROP_TYPES[type_i % PROP_TYPES.size()])
					prop.position = Vector3(t, 0, road + side * lane) if along_x else Vector3(road + side * lane, 0, t)
					prop.add_to_group("camouflage_props")
					root.add_child(prop)
					type_i += 1
				type_i += 1

static func create_prop(prop_type: String) -> StaticBody3D:
	if ModelLibrary.has_prop_model(prop_type):
		return _create_prop_from_model(prop_type)
	return _create_prop_primitive(prop_type)

static func _create_prop_from_model(prop_type: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Prop_%s" % prop_type
	body.set_meta("prop_type", prop_type)
	var target_height: float = ModelLibrary.PROP_HEIGHTS.get(prop_type, 1.1)
	var model := ModelLibrary.instance_fitted(ModelLibrary.PROP_MODELS[prop_type], target_height, true)
	if model == null:
		# O corpo acima ainda nao entrou na arvore: sem free() ele vaza no exit
		# (aparecia como "ObjectDB instances were leaked" no runner).
		body.free()
		return _create_prop_primitive(prop_type)
	body.add_child(model)
	var size: Vector3 = model.get_meta("fitted_size", Vector3(0.8, target_height, 0.8))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(0.4, size.x), maxf(0.4, size.y), maxf(0.4, size.z))
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	return body

static func _create_prop_primitive(prop_type: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Prop_%s" % prop_type
	body.set_meta("prop_type", prop_type)
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()
	match prop_type:
		"barrel":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.46
			mesh.bottom_radius = 0.5
			mesh.height = 1.3
			mesh.material = Palette.flat_material(Palette.PROP_BARREL)
			mesh_instance.mesh = mesh
			mesh_instance.position.y = 0.65
			var shape := CylinderShape3D.new()
			shape.radius = 0.5
			shape.height = 1.3
			collision.shape = shape
			collision.position.y = 0.65
		"crate":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.1, 1.1, 1.1)
			mesh.material = Palette.flat_material(Palette.PROP_CRATE)
			mesh_instance.mesh = mesh
			mesh_instance.position.y = 0.55
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.1, 1.1, 1.1)
			collision.shape = shape
			collision.position.y = 0.55
		"vase":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.26
			mesh.bottom_radius = 0.4
			mesh.height = 1.0
			mesh.material = Palette.flat_material(Palette.PROP_VASE)
			mesh_instance.mesh = mesh
			mesh_instance.position.y = 0.5
			var shape := CylinderShape3D.new()
			shape.radius = 0.4
			shape.height = 1.0
			collision.shape = shape
			collision.position.y = 0.5
		"rock":
			var mesh := SphereMesh.new()
			mesh.radius = 0.6
			mesh.height = 0.9
			mesh.material = Palette.flat_material(Palette.PROP_TIRE)
			mesh_instance.mesh = mesh
			mesh_instance.position.y = 0.42
			mesh_instance.scale = Vector3(1.1, 0.75, 1.0)
			var shape := SphereShape3D.new()
			shape.radius = 0.55
			collision.shape = shape
			collision.position.y = 0.42
		"cone":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.05
			mesh.bottom_radius = 0.3
			mesh.height = 0.75
			mesh.material = Palette.flat_material(Palette.PROP_CONE)
			mesh_instance.mesh = mesh
			mesh_instance.position.y = 0.375
			var shape := CylinderShape3D.new()
			shape.radius = 0.3
			shape.height = 0.75
			collision.shape = shape
			collision.position.y = 0.375
		"bush":
			var mesh := SphereMesh.new()
			mesh.radius = 0.62
			mesh.height = 0.95
			mesh.material = Palette.flat_material(Palette.PROP_BUSH)
			mesh_instance.mesh = mesh
			mesh_instance.position.y = 0.48
			var shape := SphereShape3D.new()
			shape.radius = 0.55
			collision.shape = shape
			collision.position.y = 0.48
		_:
			# log (tronco) e fallback generico: cilindro deitado
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.32
			mesh.bottom_radius = 0.32
			mesh.height = 1.4
			mesh.material = Palette.flat_material(Palette.PROP_TRASH_BAG)
			mesh_instance.mesh = mesh
			mesh_instance.position.y = 0.32
			mesh_instance.rotation_degrees = Vector3(0, 0, 90)
			var shape := CylinderShape3D.new()
			shape.radius = 0.32
			shape.height = 1.4
			collision.shape = shape
			collision.position.y = 0.32
			collision.rotation_degrees = Vector3(0, 0, 90)
	body.add_child(mesh_instance)
	body.add_child(collision)
	return body

static func add_box(parent: Node3D, node_name: String, box_position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Palette.flat_material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

static func fit_car_width(model: Node3D) -> Vector3:
	var size: Vector3 = model.get_meta("fitted_size", Vector3(CAR_WIDTH, 1.2, CAR_LENGTH))
	var factor := minf(1.0, CAR_WIDTH / size.x)
	model.scale *= factor
	model.position *= factor
	size *= factor
	model.set_meta("fitted_size", size)
	return size

# Sloped ends let capsule characters reach the raised pavement at crossings.
static func _add_sidewalk_span(root: Node3D, span: Vector2, lane: float, along_x: bool) -> void:
	var ramp_length := 0.8
	var low := span.x + (ramp_length if span.x > -MAP_HALF else 0.0)
	var high := span.y - (ramp_length if span.y < MAP_HALF else 0.0)
	var mid := (low + high) * 0.5
	var at := Vector3(mid, SIDEWALK_H * 0.5, lane) if along_x else Vector3(lane, SIDEWALK_H * 0.5, mid)
	var size := Vector3(high - low, SIDEWALK_H, SIDEWALK_W) if along_x else Vector3(SIDEWALK_W, SIDEWALK_H, high - low)
	add_box(root, "Sidewalk", at, size, Palette.SIDEWALK)
	if span.x > -MAP_HALF:
		_add_sidewalk_ramp(root, span.x, lane, along_x, 1.0)
	if span.y < MAP_HALF:
		_add_sidewalk_ramp(root, span.y, lane, along_x, -1.0)

static func _add_sidewalk_ramp(root: Node3D, start: float, lane: float, along_x: bool, sign_dir: float) -> void:
	var vertices := PackedVector3Array()
	for along in [0.0, 0.8]:
		for side in [-SIDEWALK_W * 0.5, SIDEWALK_W * 0.5]:
			var top: float = 0.005 if along == 0.0 else SIDEWALK_H
			for height in [-0.05, top]:
				vertices.append(Vector3(along, height, side))
	var body := StaticBody3D.new()
	body.name = "SidewalkRamp"
	body.position = Vector3(start, 0, lane) if along_x else Vector3(lane, 0, start)
	body.rotation.y = (0.0 if sign_dir > 0 else PI) if along_x else (-PI * 0.5 if sign_dir > 0 else PI * 0.5)
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([1, 3, 7, 1, 7, 5, 0, 4, 6, 0, 6, 2, 0, 1, 5, 0, 5, 4, 2, 6, 7, 2, 7, 3, 0, 2, 3, 0, 3, 1, 4, 5, 7, 4, 7, 6])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := Palette.flat_material(Palette.SIDEWALK)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	body.add_child(visual)
	root.add_child(body)
