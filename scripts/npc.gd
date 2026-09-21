extends CharacterBase

# Civil: vagueia perto de casa, pode ser roubado e revistado. Os civis usam a
# MESMA paleta dos ladroes — e isso que permite o ladrao se misturar.

const WALK_SPEED := 1.2
const ROB_COOLDOWN := 14.0
const CROWD_ALERT_RADIUS := 4.0
const CROWD_ALERT_SUSPICION := 70.0
const CROWD_RETREAT_TIME := 1.5
const CROWD_RETREAT_COOLDOWN := 2.5

var route := PackedVector3Array()
var route_index := 0
var visit_left := 0.0
var visits := 0
var home := Vector3.ZERO
var phase := 0.0
var can_be_robbed := true
# Disfarce: quando um ladrao rouba a roupa deste NPC, ele fica "roubado" —
# cai no local, some depois de alguns segundos e volta quando o ladrao troca
# de roupa de novo (assim nunca existem dois iguais na rua).
var stolen := false
var knockout_timer := 0.0
var crowd_retreat_direction := Vector3.ZERO
var crowd_retreat_left := 0.0
var crowd_alert_cooldown := 0.0

func _ready() -> void:
	phase = randf() * TAU
	suspicion = randf_range(0.0, 8.0)
	add_to_group("civilians")
	add_to_group("friskable")
	build_character(CharacterStyle.random_outfit() if character_outfit.is_empty() else character_outfit)

func knock_out() -> void:
	stolen = true
	frozen = true
	knockout_timer = 3.0
	remove_from_group("civilians")
	remove_from_group("friskable")
	set_undressed()
	if visual_holder != null:
		visual_holder.rotation.x = deg_to_rad(-82)   # cai de costas
		visual_holder.position.y = 0.2
	if checked_marker != null:
		checked_marker.visible = false

func restore() -> void:
	stolen = false
	frozen = false
	knockout_timer = 0.0
	set_outfit(character_outfit)
	if visual_holder != null:
		visual_holder.rotation.x = 0.0
		visual_holder.position = Vector3.ZERO
		visual_holder.visible = true
	if not is_in_group("civilians"):
		add_to_group("civilians")
	if not is_in_group("friskable"):
		add_to_group("friskable")

func _physics_process(delta: float) -> void:
	if stolen:
		# Caido no local; some depois de alguns segundos.
		if knockout_timer > 0.0:
			knockout_timer -= delta
			if knockout_timer <= 0.0 and visual_holder != null:
				visual_holder.visible = false
		return
	if frozen:
		return
	if crowd_alert_cooldown > 0.0:
		crowd_alert_cooldown -= delta
	if crowd_retreat_left > 0.0:
		crowd_retreat_left -= delta
		velocity.x = crowd_retreat_direction.x * WALK_SPEED
		velocity.z = crowd_retreat_direction.z * WALK_SPEED
		velocity.y = -1.0
		move_and_slide()
		return
	if crowd_alert_cooldown <= 0.0:
		var suspect: CharacterBase = _nearby_nervous_thief()
		if suspect != null:
			var away := suspect.global_position.direction_to(global_position)
			away.y = 0.0
			if away.length_squared() > 0.001:
				crowd_retreat_direction = away.normalized()
				crowd_retreat_left = CROWD_RETREAT_TIME
				crowd_alert_cooldown = CROWD_RETREAT_TIME + CROWD_RETREAT_COOLDOWN
				face_direction(-crowd_retreat_direction)
				return
	if visit_left > 0.0:
		visit_left -= delta
		velocity = Vector3.ZERO
		return
	var game := get_parent()
	if route.is_empty() or route_index >= route.size():
		# Walk between city destinations, stopping briefly on arrival.
		route = game.routes.path(global_position, game.routes.random_destination(global_position))
		route_index = 0
	while route_index < route.size() and Vector2(global_position.x - route[route_index].x, global_position.z - route[route_index].z).length() < 0.35:
		route_index += 1
	if route_index >= route.size():
		visit_left = randf_range(2.0, 5.0)
		visits += 1
		velocity = Vector3.ZERO
		return
	if CityRoutes.car_approaching(self, route[route_index]):
		velocity = Vector3.ZERO
		return
	var direction := global_position.direction_to(route[route_index])
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	velocity.y = -1.0
	face_direction(direction)
	move_and_slide()

# Civis nao conhecem a suspeita interna de ninguem: so reagem ao tremor que
# conseguem ver, quando ele ja esta muito evidente, e apenas de perto.
func _nearby_nervous_thief() -> CharacterBase:
	var nearest: CharacterBase = null
	var nearest_distance_squared := CROWD_ALERT_RADIUS * CROWD_ALERT_RADIUS
	for candidate_node in get_tree().get_nodes_in_group("thieves"):
		var candidate: CharacterBase = candidate_node as CharacterBase
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate.has_visible_tremor() or candidate.suspicion < CROWD_ALERT_SUSPICION:
			continue
		var offset := candidate.global_position - global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest

func robbed() -> void:
	can_be_robbed = false
	suspicion = minf(100.0, suspicion + 8.0)
	if body_material != null:
		body_material.albedo_color = Color("#d65959")
	var tree := get_tree()
	await tree.create_timer(0.9, false).timeout
	if body_material != null:
		body_material.albedo_color = base_color
	await tree.create_timer(ROB_COOLDOWN, false).timeout
	can_be_robbed = true
