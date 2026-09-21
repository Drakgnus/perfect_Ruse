class_name CharacterStyle
extends Object

# Personagem humanoide simples e liso (estilo boneco Mecha Chameleon): tem
# pernas, bracos, torso com roupa e cabeca. A identidade (disfarce / policia
# distinguir) vem do VESTUARIO (cor da camisa + calca) + ACESSORIO 3D (chapeu).
# Tudo procedural — ~20+ variacoes distintas.

const SHIRT_COLORS: Array[Color] = [
	Color("#d1495b"), Color("#3d7ea6"), Color("#5a9e6f"), Color("#e0a83d"),
	Color("#8d6bb0"), Color("#42b3a5"), Color("#d47a3f"), Color("#c86b96"),
	Color("#c9c4b8"), Color("#3f5566"), Color("#6a8f3c"), Color("#b0553f"),
]
const PANTS_COLORS: Array[Color] = [
	Color("#33404d"), Color("#5b4636"), Color("#4a5a6a"), Color("#6b5a3c"),
	Color("#2e3b45"), Color("#7a4a3a"),
]
const SKIN_COLORS: Array[Color] = [
	Color("#e8b58f"), Color("#c98a5e"), Color("#8d5a3c"), Color("#f0c8a0"), Color("#a56b43"),
]
const HAT_TYPES: Array[String] = ["none", "none", "cap", "beanie", "tophat", "cowboy"]
const HAT_COLORS: Array[Color] = [
	Color("#2e3138"), Color("#b03a2e"), Color("#1f6f8b"), Color("#e0a83d"),
	Color("#5a9e6f"), Color("#7d5ba6"), Color("#c9c4b8"), Color("#d47a3f"),
	Color("#3f5566"),
]
const GLASSES_TYPES: Array[String] = ["none", "none", "round", "square", "shades"]
const GLASSES_COLORS: Array[Color] = [
	Color("#2a2a2a"), Color("#5b4636"), Color("#7d5ba6"), Color("#c9c4b8"),
]
const BACKPACK_TYPES: Array[String] = ["none", "none", "pack", "satchel"]
const BACKPACK_COLORS: Array[Color] = [
	Color("#33404d"), Color("#b0553f"), Color("#5a9e6f"), Color("#8d6bb0"),
	Color("#d47a3f"),
]
const HAIR_TYPES: Array[String] = ["none", "none", "short", "mohawk", "bun"]
const HAIR_COLORS: Array[Color] = [
	Color("#2a2a2a"), Color("#5b4636"), Color("#8d5a3c"), Color("#b0553f"),
	Color("#c9a15a"),
]

static func legacy_random_outfit() -> Dictionary:
	return {
		"shirt": SHIRT_COLORS[randi() % SHIRT_COLORS.size()].to_html(),
		"pants": PANTS_COLORS[randi() % PANTS_COLORS.size()].to_html(),
		"skin": SKIN_COLORS[randi() % SKIN_COLORS.size()].to_html(),
		"hat": HAT_TYPES[randi() % HAT_TYPES.size()],
		"hat_color": HAT_COLORS[randi() % HAT_COLORS.size()].to_html(),
		"glasses": GLASSES_TYPES[randi() % GLASSES_TYPES.size()],
		"glasses_color": GLASSES_COLORS[randi() % GLASSES_COLORS.size()].to_html(),
		"backpack": BACKPACK_TYPES[randi() % BACKPACK_TYPES.size()],
		"backpack_color": BACKPACK_COLORS[randi() % BACKPACK_COLORS.size()].to_html(),
		"hair": HAIR_TYPES[randi() % HAIR_TYPES.size()],
		"hair_color": HAIR_COLORS[randi() % HAIR_COLORS.size()].to_html(),
	}

static func police_outfit() -> Dictionary:
	return {
		"shirt": Color("#2c4e88").to_html(),
		"pants": Color("#1b2f52").to_html(),
		"skin": SKIN_COLORS[randi() % SKIN_COLORS.size()].to_html(),
		"hat": "police",
		"hat_color": Color("#1b2f52").to_html(),
		"glasses": "none",
		"glasses_color": Color("#2a2a2a").to_html(),
		"backpack": "none",
		"backpack_color": Color("#1b2f52").to_html(),
		"hair": "short",
		"hair_color": Color("#2a2a2a").to_html(),
		"shoes": Palette.UNDERWEAR.to_html(),
		"jacket": false,
	}

# Constroi o humanoide dentro de um holder. Pes em y=0, olha para +Z.
static func build(holder: Node3D, outfit: Dictionary, height: float) -> void:
	var shirt := Palette.flat_material(Color(String(outfit.get("shirt", "#5a9e6f"))))
	var pants := Palette.flat_material(Color(String(outfit.get("pants", "#33404d"))))
	var skin := Palette.flat_material(Color(String(outfit.get("skin", "#e8b58f"))))

	var s := height / 1.6   # escala relativa

	# Pernas (calca)
	for side in [-1.0, 1.0]:
		_capsule(holder, 0.1 * s, 0.62 * s, Vector3(0.13 * s * side, 0.34 * s, 0), pants)
		# Sapato
		_box(holder, Vector3(0.2 * s, 0.1 * s, 0.28 * s), Vector3(0.13 * s * side, 0.05 * s, 0.04 * s), Palette.flat_material(Color("#2a2a2a")))

	# Torso (camisa)
	_capsule(holder, 0.21 * s, 0.6 * s, Vector3(0, 0.98 * s, 0), shirt)

	# Bracos (manga = camisa; mao = pele)
	for side in [-1.0, 1.0]:
		_capsule(holder, 0.072 * s, 0.5 * s, Vector3(0.29 * s * side, 0.98 * s, 0), shirt)
		_sphere(holder, 0.08 * s, Vector3(0.29 * s * side, 0.72 * s, 0), skin)

	# Cabeca (pele) + pescoco
	_capsule(holder, 0.06 * s, 0.16 * s, Vector3(0, 1.3 * s, 0), skin)
	_sphere(holder, 0.2 * s, Vector3(0, 1.45 * s, 0), skin)

	# Olhos (direcao / cara)
	for side in [-1.0, 1.0]:
		_sphere(holder, 0.035 * s, Vector3(0.075 * s * side, 1.48 * s, 0.17 * s), Palette.flat_material(Color("#2a2a2a")))

	# Acessorio no topo da cabeca
	var hat: String = String(outfit.get("hat", "none"))
	var hair: String = String(outfit.get("hair", "none"))
	if hair != "none":
		_build_hair(holder, hair, Color(String(outfit.get("hair_color", "#2a2a2a"))), 1.61 * s, 0.2 * s)
	if hat != "none":
		var hat_color := Color(String(outfit.get("hat_color", "#2e3138")))
		_build_hat(holder, hat, hat_color, 1.62 * s, 0.2 * s)
	var glasses: String = String(outfit.get("glasses", "none"))
	if glasses != "none":
		_build_glasses(holder, glasses, Color(String(outfit.get("glasses_color", "#2a2a2a"))), 1.49 * s, 0.2 * s)
	var backpack: String = String(outfit.get("backpack", "none"))
	if backpack != "none":
		_build_backpack(holder, backpack, Color(String(outfit.get("backpack_color", "#33404d"))), s)

# Constroi o personagem sem as roupas nem o acessorio do outfit. Usado quando
# a roupa foi roubada durante um disfarce: permanece apenas a cueca escura.
static func build_underwear(holder: Node3D, outfit: Dictionary, height: float) -> void:
	var skin := Palette.flat_material(Color(String(outfit.get("skin", "#e8b58f"))))
	var underwear := Palette.flat_material(Palette.UNDERWEAR)
	var s := height / 1.6

	# Pernas, torso e bracos descobertos.
	for side in [-1.0, 1.0]:
		_capsule(holder, 0.1 * s, 0.62 * s, Vector3(0.13 * s * side, 0.34 * s, 0), skin)
		_capsule(holder, 0.072 * s, 0.5 * s, Vector3(0.29 * s * side, 0.98 * s, 0), skin)
		_sphere(holder, 0.08 * s, Vector3(0.29 * s * side, 0.72 * s, 0), skin)
	_capsule(holder, 0.21 * s, 0.6 * s, Vector3(0, 0.98 * s, 0), skin)

	# Box simples na cintura, sem camisa, calca ou acessorio.
	_box(holder, Vector3(0.42 * s, 0.18 * s, 0.28 * s), Vector3(0, 0.62 * s, 0), underwear)

	# Cabeca e olhos permanecem para o NPC ainda ser reconhecivel.
	_capsule(holder, 0.06 * s, 0.16 * s, Vector3(0, 1.3 * s, 0), skin)
	_sphere(holder, 0.2 * s, Vector3(0, 1.45 * s, 0), skin)
	for side in [-1.0, 1.0]:
		_sphere(holder, 0.035 * s, Vector3(0.075 * s * side, 1.48 * s, 0.17 * s), Palette.flat_material(Palette.UNDERWEAR))

static func _build_hat(holder: Node3D, hat: String, color: Color, top: float, r: float) -> void:
	var material := Palette.flat_material(color)
	match hat:
		"cap":
			_cyl(holder, r * 0.95, r * 0.95, r * 0.7, Vector3(0, top, 0), material)
			_box(holder, Vector3(r * 1.5, r * 0.15, r * 0.9), Vector3(0, top - r * 0.2, r * 0.7), material)
		"police":
			_cyl(holder, r * 1.0, r * 1.0, r * 0.8, Vector3(0, top, 0), material)
			_box(holder, Vector3(r * 1.7, r * 0.15, r * 0.9), Vector3(0, top - r * 0.15, r * 0.8), material)
			_box(holder, Vector3(r * 0.5, r * 0.28, r * 0.1), Vector3(0, top + r * 0.15, r * 0.95), Palette.flat_material(Color("#f5c542")))
		"beanie":
			_sphere_scaled(holder, r * 1.05, Vector3(1, 0.7, 1), Vector3(0, top + r * 0.1, 0), material)
		"tophat":
			_cyl(holder, r * 0.85, r * 0.85, r * 1.4, Vector3(0, top + r * 0.6, 0), material)
			_cyl(holder, r * 1.5, r * 1.5, r * 0.12, Vector3(0, top, 0), material)
		"cowboy":
			_cyl(holder, r * 0.6, r * 0.9, r * 0.8, Vector3(0, top + r * 0.3, 0), material)
			_cyl(holder, r * 1.8, r * 1.8, r * 0.1, Vector3(0, top, 0), material)

static func _build_hair(holder: Node3D, hair: String, color: Color, top: float, r: float) -> void:
	var material := Palette.flat_material(color)
	match hair:
		"short":
			_sphere_scaled(holder, r * 1.02, Vector3(1, 0.45, 1), Vector3(0, top, 0), material)
		"mohawk":
			_box(holder, Vector3(r * 0.45, r * 0.8, r * 1.55), Vector3(0, top + r * 0.15, 0), material)
		"bun":
			_sphere(holder, r * 0.42, Vector3(0, top + r * 0.35, -r * 0.55), material)

static func _build_glasses(holder: Node3D, glasses: String, color: Color, face_y: float, r: float) -> void:
	var frame := Palette.flat_material(color)
	var lens := Palette.flat_material(Color("#27313b") if glasses == "shades" else Color("#bfe0f5"))
	var lens_radius := r * (0.34 if glasses == "round" else 0.3)
	for side in [-1.0, 1.0]:
		var x: float = side * r * 0.48
		if glasses == "square" or glasses == "shades":
			_box(holder, Vector3(r * 0.48, r * 0.32, r * 0.06), Vector3(x, face_y, r * 0.98), lens)
			_box(holder, Vector3(r * 0.57, r * 0.41, r * 0.035), Vector3(x, face_y, r * 1.01), frame)
		else:
			_sphere_scaled(holder, lens_radius, Vector3(1, 1, 0.18), Vector3(x, face_y, r * 1.0), lens)
			_sphere_scaled(holder, lens_radius * 1.18, Vector3(1, 1, 0.12), Vector3(x, face_y, r * 1.01), frame)
	_box(holder, Vector3(r * 0.22, r * 0.06, r * 0.06), Vector3(0, face_y, r * 1.0), frame)

static func _build_backpack(holder: Node3D, backpack: String, color: Color, s: float) -> void:
	var material := Palette.flat_material(color)
	if backpack == "satchel":
		_box(holder, Vector3(0.28 * s, 0.31 * s, 0.16 * s), Vector3(0.22 * s, 0.86 * s, -0.18 * s), material)
		_cyl(holder, 0.018 * s, 0.018 * s, 0.42 * s, Vector3(0.1 * s, 1.03 * s, -0.1 * s), material)
	else:
		_sphere_scaled(holder, 0.22 * s, Vector3(0.95, 1.25, 0.55), Vector3(0, 1.0 * s, -0.22 * s), material)
		_box(holder, Vector3(0.3 * s, 0.08 * s, 0.05 * s), Vector3(0, 1.04 * s, -0.36 * s), Palette.flat_material(Color("#2a2a2a")))

# --- helpers de malha ---

static func _capsule(holder: Node3D, radius: float, h: float, pos: Vector3, material: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(h, radius * 2.0)
	mesh.material = material
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	holder.add_child(inst)

static func _sphere(holder: Node3D, radius: float, pos: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = material
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	holder.add_child(inst)

static func _sphere_scaled(holder: Node3D, radius: float, scale3: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = material
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.scale = scale3
	inst.position = pos
	holder.add_child(inst)

static func _cyl(holder: Node3D, top_r: float, bottom_r: float, h: float, pos: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.material = material
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	holder.add_child(inst)

static func _box(holder: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	holder.add_child(inst)


# One shared wardrobe for civilians, thieves and the player. Outfit identity
# travels as data, so disguise never switches to a different rendering system.
const HEADWEAR: Array[String] = ["none", "cap", "beanie", "cowboy", "helmet", "headphones"]
const PRESET_NAMES: Array[String] = ["Explorador", "Urbano", "Construtora", "Viajante", "Artista", "Estudante", "Entregador", "Esportista", "Elegante", "Mecânica", "Passeio", "Músico"]
static var selected_outfit: Dictionary = {}

static func preset(index: int) -> Dictionary:
	var i := posmod(index, PRESET_NAMES.size())
	var outfit := {
		"shirt": SHIRT_COLORS[i].to_html(), "pants": PANTS_COLORS[i % PANTS_COLORS.size()].to_html(),
		"skin": SKIN_COLORS[i % SKIN_COLORS.size()].to_html(),
		"hat": ["none", "cowboy", "helmet", "none", "none", "headphones", "cap", "beanie", "none", "cowboy", "helmet", "headphones"][i], "hat_color": HAT_COLORS[i % HAT_COLORS.size()].to_html(),
		"hair": ["short", "bob", "bun"][i % 3], "hair_color": HAIR_COLORS[i % HAIR_COLORS.size()].to_html(),
		"glasses": "round" if i % 3 == 0 else "none", "glasses_color": GLASSES_COLORS[i % GLASSES_COLORS.size()].to_html(),
		"backpack": "pack" if i % 4 == 0 else "none", "backpack_color": BACKPACK_COLORS[i % BACKPACK_COLORS.size()].to_html(),
		"shoes": HAT_COLORS[(i + 3) % HAT_COLORS.size()].to_html(),
		"jacket": i % 2 == 0, "jacket_color": SHIRT_COLORS[(i + 3) % SHIRT_COLORS.size()].to_html(),
	}
	return outfit

static func random_outfit() -> Dictionary:
	var outfit := preset(randi() % PRESET_NAMES.size())
	outfit["skin"] = SKIN_COLORS.pick_random().to_html()
	outfit["shirt"] = SHIRT_COLORS.pick_random().to_html()
	outfit["pants"] = PANTS_COLORS.pick_random().to_html()
	outfit["hat"] = HEADWEAR.pick_random()
	outfit["hat_color"] = HAT_COLORS.pick_random().to_html()
	outfit["hair_color"] = HAIR_COLORS.pick_random().to_html()
	outfit["jacket_color"] = SHIRT_COLORS.pick_random().to_html()
	return outfit

static func uniform_for(previous: Dictionary) -> Dictionary:
	var uniform := police_outfit()
	for key in ["skin", "hair", "hair_color"]:
		if previous.has(key):
			uniform[key] = previous[key]
	return uniform

static func player_outfit() -> Dictionary:
	if selected_outfit.is_empty():
		var config := ConfigFile.new()
		if config.load("user://appearance.cfg") == OK:
			var saved: Variant = config.get_value("character", "outfit", {})
			if saved is Dictionary:
				selected_outfit = saved
	if selected_outfit.is_empty():
		selected_outfit = preset(0)
	# The police uniform is not selectable as a civilian cosmetic.
	if selected_outfit.get("hat", "none") == "police":
		selected_outfit["hat"] = "cap"
	return selected_outfit.duplicate(true)

static func save_player_outfit(outfit: Dictionary) -> Error:
	selected_outfit = outfit.duplicate(true)
	var config := ConfigFile.new()
	config.set_value("character", "outfit", selected_outfit)
	return config.save("user://appearance.cfg")
