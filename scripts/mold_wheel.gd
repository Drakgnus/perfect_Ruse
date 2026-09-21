class_name MoldWheel
extends Control

# Roda de moldes desenhada por codigo, no mesmo padrao da HUD. Fica escondida
# ate o jogador segurar o botao direito fora do modo de colocacao.

const RADIUS := 132.0
const CHIP := 36.0

# A roda sobe um pouco: centrada na tela, o rotulo do setor de baixo caia em
# cima da barra de acoes.
const LIFT := 56.0

var entries: Array[String] = []
var labels: Array[String] = []
var equipped := -1
var current := -1
var pointer := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open(new_entries: Array[String], new_labels: Array[String], equipped_index := -1) -> void:
	entries = new_entries.duplicate()
	labels = new_labels.duplicate()
	equipped = equipped_index
	current = -1
	pointer = Vector2.ZERO
	visible = true
	queue_redraw()

func track(offset: Vector2, index: int) -> void:
	pointer = offset
	current = index
	queue_redraw()

func close() -> void:
	visible = false
	entries.clear()
	labels.clear()
	equipped = -1
	current = -1
	queue_redraw()

func _draw() -> void:
	if entries.is_empty():
		return
	var center := size * 0.5 - Vector2(0, LIFT)
	draw_circle(center, RADIUS + CHIP + 10.0, Color(0.05, 0.08, 0.11, 0.55))
	draw_circle(center, MoldLoadout.DEAD_ZONE, Color(0.11, 0.16, 0.21, 0.85))
	var font := get_theme_default_font()
	var font_size := 15
	# Agulha: mostra para onde o movimento acumulado esta apontando, mesmo
	# quando ainda esta dentro do raio morto e nada foi escolhido.
	if pointer.length() > 4.0:
		var reach: float = minf(pointer.length(), RADIUS)
		draw_line(center, center + pointer.normalized() * reach, Color(0.96, 0.77, 0.26, 0.8), 2.0)
	for i in entries.size():
		var spot := center + MoldLoadout.sector_direction(i, entries.size()) * RADIUS
		var picked := i == current
		draw_circle(spot, CHIP, Color(0.96, 0.77, 0.26, 0.92) if picked else Color(0.13, 0.19, 0.25, 0.92))
		draw_arc(spot, CHIP, 0.0, TAU, 32, Color.WHITE if picked else Color(0.55, 0.63, 0.7, 0.9), 2.0)
		# Anel externo marca o molde que ja esta na mao, para o jogador nao
		# precisar ler a HUD antes de girar.
		if i == equipped:
			draw_arc(spot, CHIP + 6.0, 0.0, TAU, 40, Color(0.6, 0.82, 1.0, 0.85), 2.0)
		var text: String = labels[i] if i < labels.size() else entries[i].to_upper()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var text_color := Color(0.09, 0.12, 0.15) if picked else Color(0.88, 0.92, 0.95)
		draw_string(font, spot + Vector2(-width * 0.5, CHIP + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	# Legenda abaixo da roda, na folga aberta pelo LIFT: em cima ela batia no
	# painel de status, embaixo e sem o LIFT batia na barra de acoes.
	var title := "SOLTE PARA TROCAR O MOLDE"
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
	var title_at := center + Vector2(-title_width * 0.5, RADIUS + CHIP + 46.0)
	draw_rect(Rect2(title_at + Vector2(-10, -16), Vector2(title_width + 20, 24)), Color(0.05, 0.08, 0.11, 0.7))
	draw_string(font, title_at, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.82, 0.88, 0.94))
