class_name Palette
extends Object

# Paleta unica do jogo (low poly stylized: cores chapadas, sem contornos).
# REGRA DO PROJETO: todo objeto novo usa cores daqui. Consistencia visual e
# mecanica de gameplay — o dinheiro camuflado so engana se nada destoar.

const SKY := Color("#7fb2d4")
const AMBIENT := Color("#f2ede4")

const GROUND := Color("#78995f")
const ASPHALT := Color("#41474f")
const SIDEWALK := Color("#a8a49b")
const CURB := Color("#8b8880")
const ROAD_PAINT := Color("#d8d3c4")

const BUILDING_A := Color("#c98a5e")
const BUILDING_B := Color("#b0685a")
const BUILDING_C := Color("#8f9aa6")
const BUILDING_D := Color("#c9b57a")
const ROOF := Color("#6d5a4d")
const AWNING := Color("#b04f43")
const AWNING_ALT := Color("#4f7ea3")
const SIGN := Color("#324055")
const ATM_BODY := Color("#5d7a8f")
const ATM_SCREEN := Color("#bfe0d8")

const LAMP_POLE := Color("#4c5257")
const BENCH := Color("#96714a")
const PLANTER := Color("#57724b")

# Props camuflaveis (silhuetas simples e reconheciveis a distancia)
const PROP_BARREL := Color("#8c5a36")
const PROP_CRATE := Color("#ab7c42")
const PROP_VASE := Color("#5aa094")
const PROP_TIRE := Color("#2d3338")
const PROP_TRASH_BAG := Color("#242b31")
const PROP_CONE := Color("#d97b3f")
const PROP_BUSH := Color("#4f7d44")

# Personagens
const POLICE := Color("#2c4e88")
const POLICE_BEACON := Color("#e04b4b")
const NERVOUS_TINT := Color("#8a4a3f")
const CHECKED_MARK := Color("#f2f4f5")
const PLAYER_RING := Color("#e8e3cf")
const UNDERWEAR := Color("#2a2a2a")

# Civis e ladroes usam AS MESMAS cores (ladrao precisa se misturar)
const CIVILIAN_COLORS: Array[Color] = [
	Color("#5ea9d6"),
	Color("#c9a15a"),
	Color("#7f9c6b"),
	Color("#a97fa3"),
	Color("#c97b5e"),
	Color("#6fa39a"),
	Color("#9a8fb8"),
	Color("#b8b06a"),
]

static func random_civilian_color() -> Color:
	return CIVILIAN_COLORS[randi() % CIVILIAN_COLORS.size()]

static func flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	return material
