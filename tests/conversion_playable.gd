extends SceneTree
# O jogador convertido em policial precisa CONTINUAR JOGAVEL: sem frozen, sem
# resto de estado de ladrao e sem erro de script no loop do policial.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for f in 10:
		await process_frame
	var p = game.player
	p.carried_money = 300
	game.resolve_frisk(null, p)
	await process_frame
	check(p.team == "police", "virou policia")
	check(not p.frozen, "nao ficou congelado")
	check(p.is_in_group("police"), "entrou no grupo police")
	check(not p.is_in_group("thieves"), "saiu do grupo thieves")
	check(not p.is_in_group("friskable"), "nao e mais revistavel")
	check(not game.route_selecting, "route_selecting liberado")
	check(not game.alarm_targeting, "alarm_targeting liberado")
	check(game.phase == "playing", "partida continua")
	check(p.get("placement_active") != true, "modo de colocacao encerrado")
	check(p.get("police_target") == null, "sem alvo preso pendente")
	# REGRESSAO: com o jogador no grupo "police", raise_alert chamava
	# respond_to_alert em todos, e player.gd nao tinha o metodo. Cada alerta
	# quebrava a partida. Aqui o alerta e disparado de proposito.
	check(p.has_method("respond_to_alert"), "jogador-policial responde a alerta")
	check(p.has_method("witness_crime"), "jogador-policial testemunha flagrante")
	game.raise_alert(Vector3(5, 0, 5))
	await process_frame
	game.raise_alert(Vector3(-20, 0, 12))
	await process_frame
	# roda o loop do policial por um tempo: erro de script aparece aqui
	for f in 90:
		await process_frame
	check(is_instance_valid(p), "jogador continua valido apos 90 frames")
	print("CONVERSION_PLAYABLE checks=%d failures=%d" % [checks, failures.size()])
	for node in game.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	await process_frame
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
