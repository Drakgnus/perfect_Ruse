extends Node3D

const PORT: int = 7007
const MAX_CLIENTS: int = 8
const PLAYER_SCENE: PackedScene = preload("res://multiplayer_poc/poc_player.tscn")

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var address_input: LineEdit = $CanvasLayer/Panel/VBox/Address
@onready var status_label: Label = $CanvasLayer/Panel/VBox/Status

var peer: ENetMultiplayerPeer


func _ready() -> void:
	spawner.spawn_function = _spawn_player
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	status_label.text = "Escolha Host ou Cliente. Porta ENet: %d" % PORT


func _on_host_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		return
	peer = ENetMultiplayerPeer.new()
	var result: Error = peer.create_server(PORT, MAX_CLIENTS)
	if result != OK:
		status_label.text = "Nao foi possivel abrir a porta %d (%s)." % [PORT, error_string(result)]
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Host ativo na porta %d. Abra outra instancia e conecte em 127.0.0.1." % PORT
	spawner.spawn(1)


func _on_join_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		return
	peer = ENetMultiplayerPeer.new()
	var host_address: String = address_input.text.strip_edges()
	if host_address.is_empty():
		host_address = "127.0.0.1"
	var result: Error = peer.create_client(host_address, PORT)
	if result != OK:
		status_label.text = "Nao foi possivel conectar (%s)." % error_string(result)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Conectando a %s:%d..." % [host_address, PORT]


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawner.spawn(peer_id)
		status_label.text = "Cliente %d conectado." % peer_id


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player: Node = get_node_or_null("Players/%d" % peer_id)
	if player != null:
		player.queue_free()
	status_label.text = "Cliente %d desconectou." % peer_id


func _spawn_player(peer_id: Variant) -> Node:
	var player: Node3D = PLAYER_SCENE.instantiate()
	var owner_id: int = int(peer_id)
	player.name = str(owner_id)
	player.set_multiplayer_authority(owner_id)
	player.global_position = Vector3(float((owner_id % 4) * 3 - 4), 1.0, float((owner_id / 4) * 3))
	return player
