class_name GameHud
extends CanvasLayer

# HUD construida por codigo. Mostra o estado do time (meta, carregado,
# escondido), a pressao individual (suspeita e tempo sem roubar), alertas
# regionais e o overlay de fim de partida.

var goal_label: Label
var goal_bar: ProgressBar
var money_label: Label
var suspicion_label: Label
var suspicion_bar: ProgressBar
var pressure_label: Label
var mold_label: Label
var ability_label: Label
var counts_label: Label
var alert_label: Label
var blend_label: Label
var hint_label: Label
var toast_label: Label
var channel_bar: ProgressBar
var channel_label: Label
var end_overlay: ColorRect
var end_title: Label
var end_subtitle: Label
var mold_wheel: MoldWheel
var toast_timer := 0.0

# Action bar estilo MMO: cada slot guarda refs dos nós para atualizar por frame.
var action_bar: HBoxContainer
var action_slots := {}
var current_bar_mode := ""

# Ordem fixa dos slots por modo (id, tecla, nome curto)
const THIEF_SLOTS := [
	["rob", "E", "ROUBAR"],
	["copy", "C", "MOLDE"],
	["hide", "Q", "ESCONDER"],
	["decoy", "T", "ISCA"],
	["outfit", "F", "ROUPA"],
	["route", "R", "ROTA"],
	["ability", "G", "HABIL."],
]
const POLICE_SLOTS := [
	["frisk", "E", "REVISTAR"],
]

func _ready() -> void:
	_build_panel()
	_build_center_elements()
	_build_action_bar()
	_build_end_overlay()
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-6, -15)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	mold_wheel = MoldWheel.new()
	add_child(mold_wheel)

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.visible = false

func _build_panel() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.06, 0.09, 0.8)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(430, 218)
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(14, 12)
	box.size = Vector2(402, 200)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	goal_label = _make_label(box, "META DO TIME  R$ 0 / 0", 20)
	goal_bar = ProgressBar.new()
	goal_bar.min_value = 0
	goal_bar.max_value = 100
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(goal_bar)
	money_label = _make_label(box, "CARREGANDO R$ 0   ESCONDIDO R$ 0", 18)
	suspicion_label = _make_label(box, "SUSPEITA 0%", 18)
	suspicion_bar = ProgressBar.new()
	suspicion_bar.min_value = 0
	suspicion_bar.max_value = 100
	suspicion_bar.show_percentage = false
	suspicion_bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(suspicion_bar)
	pressure_label = _make_label(box, "", 15)
	mold_label = _make_label(box, "MOLDE: NENHUM", 15)
	mold_label.add_theme_color_override("font_color", Color("#f5c542"))
	ability_label = _make_label(box, "", 15)
	ability_label.add_theme_color_override("font_color", Color("#9ad0ff"))
	counts_label = _make_label(box, "", 15)
	var help := _make_label(box, "WASD andar • Shift correr  •  Mouse camera/mira  •  Esc pausa", 13)
	help.add_theme_color_override("font_color", Color("#b9c2c9"))

func _build_center_elements() -> void:
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	alert_label = Label.new()
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	alert_label.offset_top = 20
	alert_label.add_theme_font_size_override("font_size", 26)
	alert_label.add_theme_color_override("font_color", Color("#ff7373"))
	alert_label.visible = false
	top.add_child(alert_label)
	blend_label = Label.new()
	blend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blend_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	blend_label.offset_top = 58
	blend_label.text = "INDO AO DESTINO — MOUSE GIRA A CÂMERA — WASD OU R CANCELA"
	blend_label.add_theme_font_size_override("font_size", 17)
	blend_label.add_theme_color_override("font_color", Color("#a9e3a0"))
	blend_label.visible = false
	top.add_child(blend_label)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 96
	toast_label.add_theme_font_size_override("font_size", 19)
	toast_label.add_theme_color_override("font_color", Color("#f5d76e"))
	toast_label.visible = false
	top.add_child(toast_label)
	var bottom := Control.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -142
	hint_label.offset_bottom = -116
	hint_label.add_theme_font_size_override("font_size", 19)
	bottom.add_child(hint_label)
	channel_label = Label.new()
	channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	channel_label.offset_top = -212
	channel_label.offset_bottom = -184
	channel_label.add_theme_font_size_override("font_size", 19)
	channel_label.add_theme_color_override("font_color", Color("#f5d76e"))
	channel_label.visible = false
	bottom.add_child(channel_label)
	channel_bar = ProgressBar.new()
	channel_bar.min_value = 0
	channel_bar.max_value = 100
	channel_bar.show_percentage = false
	channel_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	channel_bar.offset_left = 420
	channel_bar.offset_right = -420
	channel_bar.offset_top = -180
	channel_bar.offset_bottom = -164
	channel_bar.visible = false
	bottom.add_child(channel_bar)

func _build_action_bar() -> void:
	# CenterContainer ocupa a faixa inferior e centraliza a barra automaticamente.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -104
	center.offset_bottom = -14
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	action_bar = HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 8)
	action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(action_bar)
	set_action_bar_mode("thief")

func _make_action_slot(slot_id: String, key: String, name: String) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(78, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.13, 0.86)
	style.border_color = Color(0.35, 0.42, 0.5, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	slot.add_theme_stylebox_override("panel", style)

	var key_label := Label.new()
	key_label.text = key
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	key_label.offset_top = 6
	key_label.add_theme_font_size_override("font_size", 30)
	slot.add_child(key_label)

	var name_label := Label.new()
	name_label.text = name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -26
	name_label.offset_bottom = -6
	name_label.add_theme_font_size_override("font_size", 13)
	slot.add_child(name_label)

	# Overlay de cooldown: escurece de cima para baixo + segundos no centro.
	var cd_overlay := ColorRect.new()
	cd_overlay.color = Color(0, 0, 0, 0.6)
	cd_overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.visible = false
	slot.add_child(cd_overlay)

	var cd_label := Label.new()
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_label.add_theme_font_size_override("font_size", 26)
	cd_label.add_theme_color_override("font_color", Color("#f5d76e"))
	cd_label.visible = false
	slot.add_child(cd_label)

	action_slots[slot_id] = {
		"slot": slot, "style": style, "key": key_label, "name": name_label,
		"cd_overlay": cd_overlay, "cd_label": cd_label,
	}
	return slot

func set_action_bar_mode(mode: String) -> void:
	if mode == current_bar_mode:
		return
	current_bar_mode = mode
	for child in action_bar.get_children():
		child.queue_free()
	action_slots.clear()
	var defs: Array = THIEF_SLOTS if mode == "thief" else POLICE_SLOTS
	for def in defs:
		action_bar.add_child(_make_action_slot(def[0], def[1], def[2]))

# state: { enabled, highlight, cd_ratio (0..1, 0=pronto), cd_text, name }
func update_action_slot(slot_id: String, state: Dictionary) -> void:
	if not action_slots.has(slot_id):
		return
	var refs: Dictionary = action_slots[slot_id]
	var enabled: bool = state.get("enabled", true)
	var highlight: bool = state.get("highlight", false)
	var cd_ratio: float = state.get("cd_ratio", 0.0)
	var name_override: String = state.get("name", "")
	if name_override != "":
		refs["name"].text = name_override
	var style: StyleBoxFlat = refs["style"]
	if highlight:
		style.border_color = Color("#7ee787")
		refs["key"].add_theme_color_override("font_color", Color("#7ee787"))
	elif enabled:
		style.border_color = Color(0.55, 0.62, 0.7, 1.0)
		refs["key"].add_theme_color_override("font_color", Color("#e8eef2"))
	else:
		style.border_color = Color(0.3, 0.35, 0.4, 0.7)
		refs["key"].add_theme_color_override("font_color", Color(0.5, 0.55, 0.6, 0.9))
	refs["name"].add_theme_color_override("font_color", Color("#c6cfd6") if enabled or highlight else Color(0.5, 0.55, 0.6, 0.9))
	var on_cd := cd_ratio > 0.001
	refs["cd_overlay"].visible = on_cd
	refs["cd_label"].visible = on_cd
	if on_cd:
		var slot_height: float = refs["slot"].size.y
		refs["cd_overlay"].offset_bottom = -slot_height * (1.0 - cd_ratio)
		refs["cd_label"].text = state.get("cd_text", "")

func _build_end_overlay() -> void:
	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.02, 0.03, 0.05, 0.86)
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false
	add_child(end_overlay)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -90
	box.offset_bottom = 90
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	end_overlay.add_child(box)
	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 40)
	box.add_child(end_title)
	end_subtitle = Label.new()
	end_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_subtitle.add_theme_font_size_override("font_size", 20)
	box.add_child(end_subtitle)
	var end_actions := Label.new()
	end_actions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_actions.text = "ENTER: JOGAR NOVAMENTE   •   ESC: VOLTAR AO MENU"
	end_actions.add_theme_font_size_override("font_size", 18)
	end_actions.add_theme_color_override("font_color", Color("#f5d76e"))
	box.add_child(end_actions)

func _make_label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func update_team(team_money: int, goal: int, carried: int, hidden: int) -> void:
	goal_label.text = "META DO TIME  R$ %d / %d" % [team_money, goal]
	goal_bar.value = clampf(float(team_money) / float(goal) * 100.0, 0.0, 100.0)
	money_label.text = "CARREGANDO R$ %d   ESCONDIDO R$ %d" % [carried, hidden]

func update_pressure(suspicion: float, carried: int, threshold: int) -> void:
	suspicion_label.text = "NERVOSISMO %d%%" % int(suspicion)
	suspicion_bar.value = suspicion
	if carried > threshold and suspicion > 25.0:
		pressure_label.text = "MUITO DINHEIRO NA MAO — ESCONDA (Q) OU TROQUE DE ROUPA (F)"
		pressure_label.add_theme_color_override("font_color", Color("#ff9c73"))
	elif carried > threshold:
		pressure_label.text = "CARREGANDO R$ %d — comece a ficar nervoso" % carried
		pressure_label.add_theme_color_override("font_color", Color("#e0c07a"))
	else:
		pressure_label.text = "TRANQUILO (pouco dinheiro na mao)"
		pressure_label.add_theme_color_override("font_color", Color("#b9c2c9"))

func update_counts(thieves: int, police: int) -> void:
	counts_label.text = "LADROES %d   POLICIAIS %d" % [thieves, police]

func update_ability(text: String) -> void:
	ability_label.text = text

func update_police_mode(thieves_left: int) -> void:
	ability_label.text = ""
	suspicion_label.text = "VOCE AGORA E POLICIAL"
	suspicion_bar.value = 0
	pressure_label.text = "PRENDA OS %d LADROES RESTANTES" % thieves_left
	pressure_label.add_theme_color_override("font_color", Color("#8fb7e8"))
	mold_label.text = "E  REVISTAR SUSPEITOS / INSPECIONAR OBJETOS SUSPEITOS"

func update_mold(text: String, decoys: int, max_decoys: int) -> void:
	if decoys > 0 or not text.ends_with("(copie um objeto com C)"):
		mold_label.text = "%s   ISCAS %d/%d" % [text, decoys, max_decoys]
	else:
		mold_label.text = text

func set_alert(visible_value: bool, text := "") -> void:
	alert_label.visible = visible_value
	if visible_value:
		alert_label.text = text

func set_blend(visible_value: bool) -> void:
	blend_label.visible = visible_value

func set_channel(visible_value: bool, progress := 0.0, text := "") -> void:
	channel_bar.visible = visible_value
	channel_label.visible = visible_value
	if visible_value:
		channel_bar.value = progress * 100.0
		channel_label.text = text

func set_hint(text: String) -> void:
	hint_label.text = text

func toast(text: String, duration := 2.6) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer = duration

func show_end(title: String, subtitle: String) -> void:
	end_title.text = title
	end_subtitle.text = subtitle
	end_overlay.visible = true
