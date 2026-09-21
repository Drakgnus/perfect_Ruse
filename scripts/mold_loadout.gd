class_name MoldLoadout
extends RefCounted

# Moldes de bolso: o ladrao escolhe alguns tipos ANTES da partida e pode
# coloca-los sem precisar achar o objeto na rua. Os demais continuam exigindo
# a copia no cenario (tecla C). A roda (botao direito) troca entre eles.

const SLOTS := 3
const CONFIG_PATH := "user://molds.cfg"
const DEFAULT: Array[String] = ["crate", "barrel", "bush"]
# Raio morto da roda, em pixels de mouse acumulado: sem ele um tremor da mao
# ja escolheria um setor no instante em que a roda abre.
const DEAD_ZONE := 42.0

static var chosen: Array[String] = []

static func catalog() -> Array[String]:
	return CityBuilder.PROP_TYPES.duplicate()

# Toda entrada vinda de disco ou da tela de selecao passa por aqui: tipo
# inexistente, repetido ou sobrando e descartado, e o que faltar e completado.
static func sanitize(list: Variant) -> Array[String]:
	var out: Array[String] = []
	if list is Array:
		for value in list:
			if out.size() >= SLOTS:
				break
			# str() e nao String(): o construtor recusa parte dos Variants que
			# podem vir de um arquivo de config editado a mao.
			var mold := str(value)
			if CityBuilder.PROP_TYPES.has(mold) and not out.has(mold):
				out.append(mold)
	for source in [DEFAULT, CityBuilder.PROP_TYPES]:
		for mold in source:
			if out.size() >= SLOTS:
				break
			if not out.has(mold):
				out.append(mold)
	return out

static func selected() -> Array[String]:
	if chosen.is_empty():
		var saved: Variant = []
		var config := ConfigFile.new()
		if config.load(CONFIG_PATH) == OK:
			saved = config.get_value("molds", "pocket", [])
		chosen = sanitize(saved)
	return chosen.duplicate()

static func save(list: Variant) -> Error:
	chosen = sanitize(list)
	var config := ConfigFile.new()
	config.set_value("molds", "pocket", chosen)
	return config.save(CONFIG_PATH)

static func starting_mold() -> String:
	var list := selected()
	return "" if list.is_empty() else list[0]

# A roda mostra os moldes de bolso mais o molde copiado na rua, quando este
# nao faz parte do bolso. Assim ela troca qualquer molde que o jogador tenha,
# e nunca descarta silenciosamente o que ele acabou de copiar.
static func wheel_entries(copied: String) -> Array[String]:
	var entries := selected()
	if copied != "" and not entries.has(copied):
		entries.append(copied)
	return entries

# Setor sob o cursor. No jogo o mouse fica capturado, entao a escolha vem do
# vetor acumulado de movimento, nao de uma posicao absoluta de tela.
# Setor 0 fica no topo e os demais seguem em sentido horario.
static func sector_at(offset: Vector2, count: int) -> int:
	if count <= 0 or offset.length() < DEAD_ZONE:
		return -1
	var angle := fposmod(atan2(offset.x, -offset.y), TAU)
	var step := TAU / float(count)
	return int(floor(angle / step + 0.5)) % count

# Centro visual do setor, para a roda desenhar o item no mesmo lugar que
# sector_at() considera escolhido.
static func sector_direction(index: int, count: int) -> Vector2:
	if count <= 0:
		return Vector2.ZERO
	var angle := TAU * float(index) / float(count)
	return Vector2(sin(angle), -cos(angle))
