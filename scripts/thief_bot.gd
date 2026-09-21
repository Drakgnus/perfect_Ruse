extends CharacterBase

# Ladrao controlado por IA: rouba NPCs, esconde o dinheiro camuflado e foge
# da policia. Quando e preso, o GameManager o converte em policial (GDD).

const WALK_SPEED := 2.4
const FLEE_SPEED := 4.6
const HIDE_THRESHOLD := 300
const ACTIVE_ABILITY_RANGE := 9.0

var game: Node3D
var wander_target := Vector3.ZERO
var wander_timer := 0.0
var rob_cooldown := 0.0

func _ready() -> void:
	is_thief = true
	game = get_parent()
	add_to_group("thieves")
	add_to_group("friskable")
	build_character(CharacterStyle.random_outfit())
	wander_target = _random_point()
	rob_cooldown = randf_range(2.0, 6.0)

func _physics_process(delta: float) -> void:
	if frozen or game.phase != "playing":
		return
	rob_cooldown = maxf(0.0, rob_cooldown - delta)
	var threat := _nearest_police()
	if threat != null:
		var threat_distance: float = global_position.distance_to(threat.global_position)
		if threat_distance < ACTIVE_ABILITY_RANGE and (ability == Abilities.HACKER or ability == Abilities.INFORMANT):
			game.use_ability(self)
	if threat != null and carried_money > 0 and global_position.distance_to(threat.global_position) < 6.0:
		_move_towards(global_position + threat.global_position.direction_to(global_position) * 6.0, FLEE_SPEED)
		return
	if carried_money >= HIDE_THRESHOLD:
		var prop := _nearest_camouflage_prop()
		if prop != null:
			if global_position.distance_to(prop.global_position) < 2.6:
				game.hide_money(self)
			else:
				_move_towards(prop.global_position, WALK_SPEED)
			return
	if rob_cooldown <= 0.0:
		var victim := _nearest_robbable_npc()
		if victim != null:
			if global_position.distance_to(victim.global_position) < 2.2:
				game.rob_npc(self, victim)
				rob_cooldown = randf_range(9.0, 16.0)
				wander_target = _random_point()
			else:
				_move_towards(victim.global_position, WALK_SPEED)
			return
	wander_timer -= delta
	if wander_timer <= 0.0 or global_position.distance_to(wander_target) < 1.2:
		wander_target = _random_point()
		wander_timer = randf_range(4.0, 8.0)
	_move_towards(wander_target, WALK_SPEED * 0.6)

func _move_towards(target: Vector3, speed: float) -> void:
	var direction := global_position.direction_to(target)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -1.0
	face_direction(direction)
	move_and_slide()

func _random_point() -> Vector3:
	# Circula pelas ruas do grid (linhas em CityBuilder.ROADS).
	var roads := CityBuilder.ROADS
	var half := CityBuilder.MAP_HALF - 6.0
	var r: float = roads[randi() % roads.size()]
	var t := randf_range(-half, half)
	if randf() < 0.5:
		return Vector3(t, global_position.y, r)
	return Vector3(r, global_position.y, t)

func _nearest_police() -> Node3D:
	var nearest: Node3D
	var best := INF
	for officer in get_tree().get_nodes_in_group("police"):
		var distance := global_position.distance_to(officer.global_position)
		if distance < best:
			best = distance
			nearest = officer
	return nearest

func _nearest_camouflage_prop() -> Node3D:
	var nearest: Node3D
	var best := INF
	for prop in get_tree().get_nodes_in_group("camouflage_props"):
		var distance := global_position.distance_to(prop.global_position)
		if distance < best:
			best = distance
			nearest = prop
	return nearest

func _nearest_robbable_npc() -> Node3D:
	var nearest: Node3D
	var best := 20.0
	for npc in get_tree().get_nodes_in_group("civilians"):
		if not npc.can_be_robbed:
			continue
		var distance := global_position.distance_to(npc.global_position)
		if distance < best:
			best = distance
			nearest = npc
	return nearest
