class_name CharacterBase
extends CharacterBody3D

# Base comum de todos os personagens (jogador, ladroes IA, civis, policia).
# Centraliza corpo visual, congelamento (abordagem policial), suspeita e a
# marca de "ja revistado" prevista no documento de design.

var frozen := false
var is_thief := false
var carried_money := 0
var suspicion := 0.0
var no_rob_time := 0.0
var checked_until_ms := 0
var copied_prop_type := ""
var ability := ""
var ability_cd_left := 0.0
var base_color := Color.WHITE
var body_material: StandardMaterial3D
var checked_marker: MeshInstance3D
var body_height := 1.6
var character_outfit: Dictionary = {}
var visual_holder: Node3D
var current_model: Node3D
var motion_player: AnimationPlayer

const CHAR_HEIGHT := 1.7
const TREMOR_SUSPICION_THRESHOLD := 40.0

# Os novos tells usam ondas suaves, para serem legiveis a curta distancia sem
# transformar o personagem num alvo evidente do outro lado da rua.
var nervous_tell_time := 0.0

# A policia (humana ou IA) so pode usar esta pista que ja esta visivel no corpo.
func has_visible_tremor() -> bool:
	return is_thief and suspicion >= TREMOR_SUSPICION_THRESHOLD

# Cria colisao (capsula fina), suporte visual e o marcador de "revistado".
func _init_frame(height: float) -> void:
	body_height = height
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = maxf(0.8, height)
	collision.shape = shape
	collision.position.y = height * 0.5
	add_child(collision)
	visual_holder = Node3D.new()
	visual_holder.name = "Visual"
	add_child(visual_holder)
	checked_marker = MeshInstance3D.new()
	checked_marker.name = "CheckedMarker"
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.11
	marker_mesh.height = 0.22
	marker_mesh.material = Palette.flat_material(Palette.CHECKED_MARK)
	checked_marker.mesh = marker_mesh
	checked_marker.position.y = height + 0.5
	checked_marker.visible = false
	add_child(checked_marker)

# Personagem procedural (corpo + acessorio). Guarda o outfit para o disfarce.
func build_character(outfit: Dictionary) -> void:
	_init_frame(CHAR_HEIGHT)
	set_outfit(outfit)

func set_outfit(outfit: Dictionary) -> void:
	character_outfit = outfit.duplicate()
	var holder := ModularCharacter.build(character_outfit)
	_swap_visual(holder)

func set_undressed() -> void:
	var holder := ModularCharacter.build(character_outfit, true)
	_swap_visual(holder)

# Capsula (policia sem modelo / fallback).
func build_body(radius: float, height: float, color: Color) -> void:
	_init_frame(height)
	set_capsule_visual(radius, height, color)

func set_capsule_visual(radius: float, height: float, color: Color) -> void:
	base_color = color
	body_material = Palette.flat_material(color)
	var holder := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Body"
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.material = body_material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = height * 0.5
	holder.add_child(mesh_instance)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = radius * 0.6
	head_mesh.height = radius * 1.2
	head_mesh.material = body_material
	head.mesh = head_mesh
	head.position.y = height + radius * 0.3
	holder.add_child(head)
	_swap_visual(holder)

func _swap_visual(node: Node3D) -> void:
	if current_model != null and is_instance_valid(current_model):
		current_model.visible = false
		current_model.queue_free()
	current_model = node
	visual_holder.add_child(node)
	motion_player = ModularCharacter.animation_player(node)
	ModularCharacter.play_motion(motion_player, 0.0, true)

func set_frozen(value: bool) -> void:
	frozen = value
	if frozen:
		velocity = Vector3.ZERO

func is_checked() -> bool:
	return Time.get_ticks_msec() < checked_until_ms

func mark_checked(duration_seconds: float) -> void:
	checked_until_ms = Time.get_ticks_msec() + int(duration_seconds * 1000.0)

func apply_color(color: Color) -> void:
	base_color = color
	if body_material != null:
		body_material.albedo_color = color

func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.001:
		look_at(global_position + flat, Vector3.UP, true)

func _process(delta: float) -> void:
	var match_stopped: bool = get_parent().get("phase") != null and get_parent().get("phase") != "playing"
	ModularCharacter.play_motion(motion_player, Vector2(velocity.x, velocity.z).length(), frozen or match_stopped)
	if checked_marker:
		checked_marker.visible = is_checked()
	# Pista visual de nervosismo: o ladrao TREME e SUA conforme a suspeita sobe.
	# E o que permite um POLICIAL HUMANO identificar o suspeito na multidao.
	# Civis nao roubam -> suspeita baixa -> nao tremem (o tremor denuncia o ladrao).
	if is_thief and visual_holder != null and not frozen:
		var nervous := clampf((suspicion - TREMOR_SUSPICION_THRESHOLD) / 60.0, 0.0, 1.0)
		if nervous > 0.02:
			var amp := nervous * 0.05
			visual_holder.position = Vector3(randf_range(-amp, amp), 0.0, randf_range(-amp, amp))
			visual_holder.rotation.z = 0.0 # Keep soles on the support plane; horizontal tremor remains.
			# Olha de um lado para o outro sem girar o personagem de fato: a
			# direcao de movimento continua sob controle do jogador/IA.
			nervous_tell_time += delta
			if current_model != null:
				var scan_yaw := sin(nervous_tell_time * 1.7) * deg_to_rad(6.0) * nervous
				current_model.rotation.y = scan_yaw
				# Ao caminhar, um pequeno desvio visual lateral deixa o passo menos
				# regular. O maximo de 2,5 cm so aparece bem de perto.
				var horizontal_speed := Vector2(velocity.x, velocity.z).length()
				var walking := clampf(horizontal_speed / 2.0, 0.0, 1.0)
				current_model.position.x = sin(nervous_tell_time * 5.1) * 0.025 * nervous * walking
			_update_sweat(nervous, delta)
		else:
			_reset_nervous_tells()
			_update_sweat(0.0, delta)
	elif visual_holder != null and (not is_thief or not frozen):
		_reset_nervous_tells()

func _reset_nervous_tells() -> void:
	visual_holder.position = Vector3.ZERO
	visual_holder.rotation.z = 0.0
	if current_model != null:
		current_model.rotation.y = 0.0
		current_model.position.x = 0.0

var sweat_drops: Array[MeshInstance3D] = []
var sweat_phase := 0.0

func _update_sweat(nervous: float, delta: float) -> void:
	if nervous <= 0.35:
		for drop in sweat_drops:
			drop.visible = false
		return
	if sweat_drops.is_empty():
		for i in 2:
			var drop := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.05
			mesh.height = 0.11
			var material := Palette.flat_material(Color("#bfe0f5"))
			material.emission_enabled = true
			material.emission = Color("#7fc5e8")
			mesh.material = material
			drop.mesh = mesh
			add_child(drop)
			sweat_drops.append(drop)
	sweat_phase += delta * 2.2
	for i in sweat_drops.size():
		var drop := sweat_drops[i]
		drop.visible = true
		var fall := fmod(sweat_phase + i * 0.5, 1.0)
		var side := 0.16 if i == 0 else -0.16
		drop.position = Vector3(side, body_height * 0.62 - fall * 0.5, 0.16)
