class_name PropLabels
extends RefCounted

# Nome dos moldes na tela. Ficava so no main.gd, mas o menu de pre-partida e a
# roda tambem precisam, e la o mapa estava desatualizado: "rock" e "log" caiam
# no fallback em ingles enquanto "tire"/"trash_bag" nem existem mais.
const MAP := {
	"barrel": "BARRIL",
	"crate": "CAIXA",
	"vase": "VASO",
	"rock": "PEDRA",
	"log": "TORA",
	"cone": "CONE",
	"bush": "ARBUSTO",
}

static func of(prop_type: String) -> String:
	return String(MAP.get(prop_type, prop_type.to_upper()))
