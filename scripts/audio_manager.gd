class_name AudioManager
extends Node

# Efeitos curtos do Kenney Interface Sounds (CC0). O manager apenas toca
# eventos; o GameManager continua decidindo quando cada um acontece.

const EVENT_STREAMS: Dictionary[String, AudioStream] = {
	"robbery": preload("res://assets/audio/robbery.ogg"),
	"alarm": preload("res://assets/audio/alarm.ogg"),
	"frisk": preload("res://assets/audio/frisk.ogg"),
	"conversion": preload("res://assets/audio/conversion.ogg"),
	"hide_money": preload("res://assets/audio/hide_money.ogg"),
	"retrieve_money": preload("res://assets/audio/retrieve_money.ogg"),
	"victory": preload("res://assets/audio/victory.ogg"),
	"defeat": preload("res://assets/audio/defeat.ogg"),
}

const EVENT_COOLDOWNS_MS: Dictionary[String, int] = {
	"robbery": 140,
	"alarm": 1200,
	"frisk": 500,
	"conversion": 700,
	"hide_money": 180,
	"retrieve_money": 180,
	"victory": 0,
	"defeat": 0,
}

var players: Dictionary[String, AudioStreamPlayer] = {}
var last_played_ms: Dictionary[String, int] = {}

func _ready() -> void:
	for event_name: String in EVENT_STREAMS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "%sSound" % event_name.capitalize()
		player.stream = EVENT_STREAMS[event_name]
		player.volume_db = -6.0
		add_child(player)
		players[event_name] = player

func play(event_name: String) -> void:
	if not players.has(event_name):
		push_warning("Audio event desconhecido: %s" % event_name)
		return
	var now_ms: int = Time.get_ticks_msec()
	var previous_ms: int = last_played_ms.get(event_name, -1000000)
	var cooldown_ms: int = EVENT_COOLDOWNS_MS.get(event_name, 0)
	if now_ms - previous_ms < cooldown_ms:
		return
	last_played_ms[event_name] = now_ms
	var player: AudioStreamPlayer = players[event_name]
	player.play()

# Encerrar a partida (inclusive via --quit-after nos testes) com um one-shot
# ainda tocando deixava o recurso OGG em uso e o motor reprovava a saida com
# "resources still in use at exit". O manager passa a silenciar a si mesmo.
func stop_all() -> void:
	for key in players:
		var p: AudioStreamPlayer = players[key]
		if is_instance_valid(p):
			p.stop()
			p.stream = null

func _exit_tree() -> void:
	stop_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop_all()
