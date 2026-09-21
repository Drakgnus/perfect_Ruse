extends Node3D

const SPEED: float = 5.0

@export var network_position: Vector3 = Vector3.ZERO
@export var network_rotation_y: float = 0.0

var input_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	if multiplayer.is_server():
		network_position = global_position
		network_rotation_y = rotation.y


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var local_input: Vector2 = _read_local_input()
		if multiplayer.is_server():
			input_direction = local_input
		else:
			submit_input.rpc_id(1, local_input)
	if multiplayer.is_server():
		_simulate_server_movement(delta)
	else:
		global_position = global_position.lerp(network_position, minf(delta * 14.0, 1.0))
		rotation.y = lerp_angle(rotation.y, network_rotation_y, minf(delta * 14.0, 1.0))


func _simulate_server_movement(delta: float) -> void:
	var movement: Vector3 = Vector3(input_direction.x, 0.0, input_direction.y)
	if movement.length_squared() > 0.0:
		movement = movement.normalized()
		global_position += movement * SPEED * delta
		rotation.y = atan2(-movement.x, -movement.z)
	network_position = global_position
		network_rotation_y = rotation.y


func _read_local_input() -> Vector2:
	var horizontal: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var vertical: float = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return Vector2(horizontal, vertical).limit_length(1.0)


@rpc("any_peer", "unreliable")
func submit_input(new_input: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		return
	input_direction = new_input.limit_length(1.0)
