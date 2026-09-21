class_name ModelLibrary
extends Object

# Carrega os modelos low poly do Kenney (CC0) e os ajusta a uma altura-alvo,
# gerando colisao automatica pela AABB. Se um modelo faltar, cai no primitivo
# equivalente (mantendo o jogo jogavel mesmo sem os assets importados).

const PROP_MODELS := {
	"barrel": "res://assets/models/survival/prop_barrel.glb",
	"crate": "res://assets/models/survival/prop_crate.glb",
	"vase": "res://assets/models/prop_vase.glb",
	"rock": "res://assets/models/survival/prop_rock.glb",
	"log": "res://assets/models/survival/prop_log.glb",
	"cone": "res://assets/models/prop_cone.glb",
	"bush": "res://assets/models/prop_bush.glb",
}

const PROP_HEIGHTS := {
	"barrel": 1.2,
	"crate": 1.1,
	"vase": 1.0,
	"rock": 1.1,
	"log": 0.9,
	"cone": 0.85,
	"bush": 1.15,
}

const BUILDING_MODELS := {
	"a": "res://assets/models/city/building_a.glb",
	"b": "res://assets/models/city/building_b.glb",
	"c": "res://assets/models/city/building_c.glb",
	"d": "res://assets/models/city/building_d.glb",
}
# --- City Kit (Kenney, CC0) — instalado 2026-09-20 ---------------------------
const DOWNTOWN_BUILDINGS := [
	"res://assets/models/citykit/commercial/building-a.glb",
	"res://assets/models/citykit/commercial/building-b.glb",
	"res://assets/models/citykit/commercial/building-c.glb",
	"res://assets/models/citykit/commercial/building-d.glb",
	"res://assets/models/citykit/commercial/building-e.glb",
	"res://assets/models/citykit/commercial/building-f.glb",
	"res://assets/models/citykit/commercial/building-g.glb",
	"res://assets/models/citykit/commercial/building-h.glb",
	"res://assets/models/citykit/commercial/building-i.glb",
	"res://assets/models/citykit/commercial/building-j.glb",
	"res://assets/models/citykit/commercial/building-k.glb",
	"res://assets/models/citykit/commercial/building-l.glb",
	"res://assets/models/citykit/commercial/building-m.glb",
	"res://assets/models/citykit/commercial/building-n.glb",
]
const TOWER_BUILDINGS := [
	"res://assets/models/citykit/commercial/building-skyscraper-a.glb",
	"res://assets/models/citykit/commercial/building-skyscraper-b.glb",
	"res://assets/models/citykit/commercial/building-skyscraper-c.glb",
	"res://assets/models/citykit/commercial/building-skyscraper-d.glb",
	"res://assets/models/citykit/commercial/building-skyscraper-e.glb",
]
const SUBURB_BUILDINGS := [
	"res://assets/models/citykit/suburban/building-type-a.glb",
	"res://assets/models/citykit/suburban/building-type-b.glb",
	"res://assets/models/citykit/suburban/building-type-c.glb",
	"res://assets/models/citykit/suburban/building-type-d.glb",
	"res://assets/models/citykit/suburban/building-type-e.glb",
	"res://assets/models/citykit/suburban/building-type-f.glb",
	"res://assets/models/citykit/suburban/building-type-g.glb",
	"res://assets/models/citykit/suburban/building-type-h.glb",
	"res://assets/models/citykit/suburban/building-type-i.glb",
	"res://assets/models/citykit/suburban/building-type-j.glb",
	"res://assets/models/citykit/suburban/building-type-k.glb",
	"res://assets/models/citykit/suburban/building-type-l.glb",
	"res://assets/models/citykit/suburban/building-type-m.glb",
	"res://assets/models/citykit/suburban/building-type-n.glb",
	"res://assets/models/citykit/suburban/building-type-o.glb",
	"res://assets/models/citykit/suburban/building-type-p.glb",
	"res://assets/models/citykit/suburban/building-type-q.glb",
	"res://assets/models/citykit/suburban/building-type-r.glb",
	"res://assets/models/citykit/suburban/building-type-s.glb",
	"res://assets/models/citykit/suburban/building-type-t.glb",
	"res://assets/models/citykit/suburban/building-type-u.glb",
]
const STORE_DETAILS := [
	"res://assets/models/citykit/commercial/detail-awning.glb",
	"res://assets/models/citykit/commercial/detail-awning-wide.glb",
	"res://assets/models/citykit/commercial/detail-overhang.glb",
	"res://assets/models/citykit/commercial/detail-overhang-wide.glb",
]
const PARK_TREES := [
	"res://assets/models/citykit/suburban/tree-large.glb",
	"res://assets/models/citykit/suburban/tree-small.glb",
	"res://assets/models/tree.glb",
]
const STREET_LIGHTS := [
	"res://assets/models/citykit/roads/light-curved.glb",
	"res://assets/models/citykit/roads/light-curved-double.glb",
	"res://assets/models/citykit/roads/light-square.glb",
	"res://assets/models/citykit/roads/light-square-double.glb",
]
const STREET_SIGNS := [
	"res://assets/models/citykit/roads/road-sign-stop.glb",
	"res://assets/models/citykit/roads/road-sign-street.glb",
	"res://assets/models/citykit/roads/road-sign-warning.glb",
]
const STREET_CLUTTER := [
	"res://assets/models/citykit/roads/construction-barrier.glb",
	"res://assets/models/citykit/roads/construction-cone.glb",
	"res://assets/models/citykit/roads/dumpster.glb",
	"res://assets/models/citykit/roads/electricity-pole.glb",
	"res://assets/models/citykit/suburban/planter.glb",
	"res://assets/models/citykit/suburban/tree-large.glb",
	"res://assets/models/citykit/suburban/tree-small.glb",
]

const AWNING_MODEL := "res://assets/models/city/detail_awning.glb"
const TREE_MODEL := "res://assets/models/tree.glb"

const CAR_MODELS := [
	"res://assets/models/cars/sedan.glb",
	"res://assets/models/cars/suv.glb",
	"res://assets/models/cars/taxi.glb",
	"res://assets/models/cars/van.glb",
	"res://assets/models/cars/hatchback_sports.glb",
	"res://assets/models/cars/sedan_sports.glb",
]
const POLICE_CAR_MODEL := "res://assets/models/cars/police_car.glb"

static func random_car_model() -> String:
	return CAR_MODELS[randi() % CAR_MODELS.size()]

static func has_cars() -> bool:
	return ResourceLoader.exists(CAR_MODELS[0])

# Personagens humanoides low poly (Kenney Mini Characters). O disfarce copia o
# modelo EXATO do NPC, entao civis e ladroes usam o mesmo conjunto.
# Blocky Characters — SO cidadaos normais (roupas comuns, ternos, senhores).
# Excluidos: zumbis (l, o), ninja (h), fantasias (d, f, g), quimono (n).
const CHARACTER_MODELS := [
	"res://assets/models/blocky/b_a.glb",
	"res://assets/models/blocky/b_b.glb",
	"res://assets/models/blocky/b_c.glb",
	"res://assets/models/blocky/b_e.glb",
	"res://assets/models/blocky/b_i.glb",
	"res://assets/models/blocky/b_j.glb",
	"res://assets/models/blocky/b_k.glb",
	"res://assets/models/blocky/b_m.glb",
	"res://assets/models/blocky/b_p.glb",
	"res://assets/models/blocky/b_q.glb",
]
# Modelo reservado para a policia (tingido de azul, entao a skin base pouco importa).
const POLICE_CHARACTER := "res://assets/models/blocky/b_r.glb"
const CHARACTER_HEIGHT := 1.7

static func has_characters() -> bool:
	return ResourceLoader.exists(CHARACTER_MODELS[0])

static func random_character_model() -> String:
	return CHARACTER_MODELS[randi() % CHARACTER_MODELS.size()]

# Altura nativa dos Blocky Characters (riggados). Fit por AABB nao funciona
# bem com malha skinada, entao usamos escala fixa.
const CHARACTER_NATIVE_HEIGHT := 2.7

# Instancia um personagem em pe (pes em y=0), virado para +Z.
static func instance_character(path: String) -> Node3D:
	var model := instance_model(path)
	if model == null:
		return null
	model.scale = Vector3.ONE * (CHARACTER_HEIGHT / CHARACTER_NATIVE_HEIGHT)
	return model

# Material azul solido para a policia — uniforme claramente distinto da multidao.
static func police_tint_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#2c4e88")
	material.roughness = 1.0
	return material

static func apply_material_override(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		apply_material_override(child, material)

static func has_prop_model(prop_type: String) -> bool:
	return PROP_MODELS.has(prop_type) and ResourceLoader.exists(PROP_MODELS[prop_type])

static func instance_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D

# Instancia um modelo, escala e apoia a base em y=0.
# fit_by_max=false: escala pela ALTURA (predios altos).
# fit_by_max=true: escala pela MAIOR dimensao (props: evita tronco comprido).
static func instance_fitted(path: String, target: float, fit_by_max := false) -> Node3D:
	var model := instance_model(path)
	if model == null:
		return null
	var box := combined_aabb(model, Transform3D.IDENTITY)
	var reference := box.size.y
	if fit_by_max:
		reference = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if reference > 0.0001:
		var scale_factor := target / reference
		model.scale = Vector3.ONE * scale_factor
		box = AABB(box.position * scale_factor, box.size * scale_factor)
	# Apoia a base no chao e centraliza horizontalmente.
	model.position = Vector3(-box.position.x - box.size.x * 0.5, -box.position.y, -box.position.z - box.size.z * 0.5)
	model.set_meta("fitted_size", box.size)
	return model

static func combined_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var has_any := false
	if node is VisualInstance3D:
		var local: AABB = node.get_aabb()
		var world := xform * local
		result = world
		has_any = true
	for child in node.get_children():
		var child_xform := xform
		if child is Node3D:
			child_xform = xform * child.transform
		var child_aabb := combined_aabb(child, child_xform)
		if child_aabb.size == Vector3.ZERO:
			continue
		if has_any:
			result = result.merge(child_aabb)
		else:
			result = child_aabb
			has_any = true
	return result

# Aplica um material translucido em todas as malhas (usado pelo fantasma de
# colocacao). Funciona tanto no primitivo quanto no modelo importado.
static func apply_ghost_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	if node is CollisionShape3D:
		node.disabled = true
	for child in node.get_children():
		apply_ghost_material(child, material)
