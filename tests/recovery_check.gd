extends SceneTree
# O dinheiro tem de VOLTAR para a policia: a apreensao na revista e a
# recuperacao de um esconderijo precisam DERRUBAR team_money(), nao apenas
# somar um contador separado.
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

	# --- 1) apreensao na revista ---
	var thieves: Array = game.get_tree().get_nodes_in_group("thieves")
	if thieves.is_empty():
		printerr("FAIL: sem ladroes na cena")
		_finish(game)
		return
	var thief: CharacterBase = thieves[0]
	thief.carried_money = 500
	var before: int = game.team_money()
	var recovered_before: int = game.recovered_money
	game.resolve_frisk(null, thief)
	await process_frame
	check(game.team_money() == before - 500, "revista tira 500 do time")
	check(game.recovered_money == recovered_before + 500, "revista devolve 500 a policia")

	# --- 2) recuperacao de esconderijo ---
	thieves = game.get_tree().get_nodes_in_group("thieves")
	if thieves.is_empty():
		_report(game)
		return
	var thief2: CharacterBase = thieves[0]
	thief2.global_position = Vector3(2.0, 0.2, 2.0)   # asfalto do cruzamento central
	thief2.carried_money = 400
	# esconder exige MOLDE copiado (tecla C no jogo)
	thief2.copied_prop_type = "crate"
	await process_frame
	var hid: bool = game.hide_money_at(thief2, Vector3(3.0, 0.0, 2.0))
	check(hid, "escondeu 400 em ponto valido da rua")
	await process_frame
	if hid and not game.placed_objects.is_empty():
		var hidden_before: int = game.hidden_money()
		var team_before: int = game.team_money()
		var recovered_mid: int = game.recovered_money
		check(hidden_before >= 400, "dinheiro consta como escondido")
		var stash: Node3D = game.placed_objects[0]["node"]
		game.recover_stash(null, stash)
		await process_frame
		check(game.team_money() == team_before - 400, "recuperar esconderijo tira 400 do time")
		check(game.recovered_money == recovered_mid + 400, "esconderijo devolve 400 a policia")
	_report(game)

func _report(game: Node) -> void:
	print("RECOVERY_CHECK checks=%d failures=%d" % [checks, failures.size()])
	_finish(game)

func _finish(game: Node) -> void:
	for node in game.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	await process_frame
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
