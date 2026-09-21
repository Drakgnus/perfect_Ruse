class_name Abilities
extends Object

# Habilidades dos ladroes (GDD). Cada ladrao recebe UMA no spawn.
# Passivas: aplicadas automaticamente por checagens no GameManager.
# Ativas: acionadas com a tecla G (cooldown proprio).

const THIEF_EXPERT := "thief_expert"      # passiva: roubo canalizado 40% mais rapido
const PICKPOCKET := "pickpocket"          # passiva: +50% ao roubar NPC
const SMUGGLER := "smuggler"              # passiva: suspeita sobe mais devagar
const CAMOUFLAGER := "camouflager"        # passiva: limite de iscas dobrado
const HACKER := "hacker"                  # ativa: alarme falso em regiao aleatoria
const INFORMANT := "informant"            # ativa: revela policiais por alguns segundos

const ALL: Array[String] = [THIEF_EXPERT, PICKPOCKET, SMUGGLER, CAMOUFLAGER, HACKER, INFORMANT]
const ACTIVE: Array[String] = [HACKER, INFORMANT]

const COOLDOWNS := {
	HACKER: 25.0,
	INFORMANT: 30.0,
}

const INFO := {
	THIEF_EXPERT: { "name": "Especialista em Furtos", "desc": "Roubos de loja/ATM 40% mais rapidos.", "key": "passiva" },
	PICKPOCKET: { "name": "Batedor de Carteiras", "desc": "+50% de dinheiro ao roubar NPCs.", "key": "passiva" },
	SMUGGLER: { "name": "Contrabandista", "desc": "Sua suspeita sobe mais devagar.", "key": "passiva" },
	CAMOUFLAGER: { "name": "Camuflador", "desc": "Pode colocar o dobro de iscas.", "key": "passiva" },
	HACKER: { "name": "Hackeador", "desc": "G: abre o mapa e dispara alarme onde clicar.", "key": "G" },
	INFORMANT: { "name": "Informante", "desc": "G: revela os policiais por 6s.", "key": "G" },
}

static func random_ability() -> String:
	return ALL[randi() % ALL.size()]

static func is_active(ability: String) -> bool:
	return ability in ACTIVE

static func cooldown(ability: String) -> float:
	return COOLDOWNS.get(ability, 0.0)

static func display_name(ability: String) -> String:
	return String(INFO.get(ability, {}).get("name", ability))

static func description(ability: String) -> String:
	return String(INFO.get(ability, {}).get("desc", ""))
