extends CharacterBase

# Policial (bot). Implementa o fluxo do GDD:
# patrulhar -> receber alerta -> investigar a regiao -> abordar suspeito
# (Etapa 1: paralisar; Etapa 2: revistar) -> prender/converter ou liberar
# com marca temporaria -> procurar dinheiro escondido perto do alerta.

const PATROL_SPEED := 2.2
const INVESTIGATE_SPEED := 4.2
const APPROACH_SPEED := 4.8
const PARALYZE_TIME := 1.0
const FRISK_TIME := 2.0
const INSPECT_TIME := 1.6
const OBSERVATION_RANGE := 22.0
const OBSERVATION_CONE_COS := 0.57
const FLEE_SPEED := 4.0

enum State { PATROL, INVESTIGATE, APPROACH, PARALYZE, FRISK, GOTO_STASH, INSPECT }

var game: Node3D
var state: int = State.PATROL
var patrol_home := Vector3.ZERO
var patrol_phase := 0.0
var target: CharacterBase
var stash_target: Node3D
var state_timer := 0.0
var scan_timer := 0.0
var beacon_material: StandardMaterial3D

func _ready() -> void:
	game = get_parent()
	patrol_home = global_position
	patrol_phase = randf() * TAU
	add_to_group("police")
	build_character(CharacterStyle.police_outfit() if character_outfit.is_empty() else character_outfit)
	var beacon := MeshInstance3D.new()
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.13
	beacon_mesh.bottom_radius = 0.13
	beacon_mesh.height = 0.16
	beacon_material = Palette.flat_material(Palette.POLICE_BEACON)
	beacon_mesh.material = beacon_material
	beacon.mesh = beacon_mesh
	beacon.position.y = body_height + 0.75
	add_child(beacon)

func _physics_process(delta: float) -> void:
	if game.phase != "playing":
		velocity = Vector3.ZERO
		return
	beacon_material.emission_enabled = state != State.PATROL
	beacon_material.emission = Palette.POLICE_BEACON
	match state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			_investigate(delta)
		State.APPROACH:
			_approach(delta)
		State.PARALYZE:
			_paralyze_stage(delta)
		State.FRISK:
			_frisk_stage(delta)
		State.GOTO_STASH:
			_goto_stash(delta)
		State.INSPECT:
			_inspect_stash(delta)

func respond_to_alert(_origin: Vector3) -> void:
	if state in [State.PARALYZE, State.FRISK]:
		return
	_release_target()
	stash_target = null
	state = State.INVESTIGATE

# Flagrante: viu o ladrao roubando — vai direto abordar (ignora o cone dai pra frente).
func witness_crime(thief: CharacterBase) -> void:
	if state in [State.PARALYZE, State.FRISK]:
		return
	_release_target()
	stash_target = null
	target = thief
	state = State.APPROACH

func _patrol(delta: float) -> void:
	patrol_phase += delta
	var target_position := patrol_home + Vector3(sin(patrol_phase * 0.5) * 3.0, 0, cos(patrol_phase * 0.4) * 3.0)
	_move_towards(target_position, PATROL_SPEED)
	if game.alert_is_active():
		state = State.INVESTIGATE
		return
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 1.0
		# So aborda pistas que um policial humano tambem conseguiria observar.
		var suspect := _pick_suspect(global_position, 12.0)
		if suspect != null:
			target = suspect
			state = State.APPROACH

func _investigate(delta: float) -> void:
	if not game.alert_is_active():
		state = State.PATROL
		return
	var origin: Vector3 = game.alert_origin
	if global_position.distance_to(origin) > 4.0:
		_move_towards(origin, INVESTIGATE_SPEED)
		return
	var suspect := _pick_suspect(origin, 10.0)
	if suspect != null:
		target = suspect
		state = State.APPROACH
		return
	var stash: Node3D = game.claim_suspect_stash(self)
	if stash != null:
		stash_target = stash
		state = State.GOTO_STASH
		return
	_move_towards(origin + Vector3(sin(patrol_phase) * 2.0, 0, cos(patrol_phase) * 2.0), PATROL_SPEED)
	patrol_phase += delta

func _approach(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.is_checked():
		target = null
		state = State.INVESTIGATE if game.alert_is_active() else State.PATROL
		return
	var distance := global_position.distance_to(target.global_position)
	if distance > 1.9:
		_move_towards(target.global_position, APPROACH_SPEED)
		return
	# Etapa 1: paralisar.
	target.set_frozen(true)
	velocity = Vector3.ZERO
	state_timer = PARALYZE_TIME
	state = State.PARALYZE
	game.on_approach_started(self, target)

func _paralyze_stage(delta: float) -> void:
	if not _target_still_valid():
		return
	state_timer -= delta
	if state_timer <= 0.0:
		state_timer = FRISK_TIME
		state = State.FRISK

func _frisk_stage(delta: float) -> void:
	if not _target_still_valid():
		return
	state_timer -= delta
	if state_timer <= 0.0:
		# Etapa 2: revista concluida — o GameManager decide prender ou liberar.
		var frisked := target
		target = null
		state = State.PATROL
		game.resolve_frisk(self, frisked)

func _goto_stash(_delta: float) -> void:
	if stash_target == null or not is_instance_valid(stash_target):
		stash_target = null
		state = State.PATROL
		return
	if global_position.distance_to(stash_target.global_position) > 1.7:
		_move_towards(stash_target.global_position, INVESTIGATE_SPEED)
		return
	velocity = Vector3.ZERO
	state_timer = INSPECT_TIME
	state = State.INSPECT

func _inspect_stash(delta: float) -> void:
	if stash_target == null or not is_instance_valid(stash_target):
		stash_target = null
		state = State.PATROL
		return
	state_timer -= delta
	if state_timer <= 0.0:
		var found := stash_target
		stash_target = null
		state = State.PATROL
		game.recover_stash(self, found)

func _target_still_valid() -> bool:
	if target == null or not is_instance_valid(target):
		target = null
		state = State.PATROL
		return false
	return true

func _release_target() -> void:
	if target != null and is_instance_valid(target):
		target.set_frozen(false)
	target = null

func _pick_suspect(center: Vector3, radius: float) -> CharacterBase:
	var best_score := -INF
	var best: CharacterBase
	for node in get_tree().get_nodes_in_group("friskable"):
		var candidate: CharacterBase = node as CharacterBase
		if candidate == null:
			continue
		if candidate.frozen or candidate.is_checked():
			continue
		var distance: float = center.distance_to(candidate.global_position)
		if distance > radius:
			continue
		if not _can_observe(candidate):
			continue
		var score: float = -distance
		if score > best_score:
			best_score = score
			best = candidate
	return best

# Mesma regra de visao usada no flagrante: alcance, cone e linha de visao.
# E chamada apenas a partir de _physics_process, onde o raycast e seguro.
func _can_observe(candidate: CharacterBase) -> bool:
	var to_candidate: Vector3 = candidate.global_position - global_position
	to_candidate.y = 0.0
	var distance: float = to_candidate.length()
	if distance > OBSERVATION_RANGE or distance < 0.5:
		return false
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return false
	if forward.normalized().dot(to_candidate.normalized()) < OBSERVATION_CONE_COS:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var officer_eye: Vector3 = global_position + Vector3(0, 1.4, 0)
	var candidate_eye: Vector3 = candidate.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(officer_eye, candidate_eye)
	query.exclude = [get_rid(), candidate.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return false
	return candidate.has_visible_tremor() or _is_clearly_fleeing_or_carrying(candidate)

func _is_clearly_fleeing_or_carrying(candidate: CharacterBase) -> bool:
	var horizontal_velocity := candidate.velocity
	horizontal_velocity.y = 0.0
	var moving_away: bool = horizontal_velocity.length() >= FLEE_SPEED \
		and horizontal_velocity.normalized().dot(global_position.direction_to(candidate.global_position)) > 0.65
	return moving_away or candidate.carried_money > 0

func _move_towards(target_position: Vector3, speed: float) -> void:
	var direction := global_position.direction_to(target_position)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -1.0
	face_direction(direction)
	move_and_slide()
