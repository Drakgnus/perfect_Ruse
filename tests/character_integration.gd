extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var outfits: Dictionary = {}
	for i in 12:
		var outfit := CharacterStyle.preset(i)
		outfits[var_to_str(outfit)] = true
		var visual := ModularCharacter.build(outfit)
		root.add_child(visual)
		var ap := ModularCharacter.animation_player(visual)
		check(ap != null, "AnimationPlayer preset %d" % i)
		if ap:
			for clip in ["idle", "walk", "run"]:
				check(ap.has_animation(clip), "clip %s preset %d" % [clip, i])
			ModularCharacter.play_motion(ap, 1.6, false)
			ap.advance(0.1)
			var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
			check(skeleton != null, "skeleton exists")
			if skeleton:
				var bone := skeleton.find_bone("mixamorig_LeftUpLeg")
				if bone < 0:
					bone = skeleton.find_bone("mixamorig:LeftUpLeg")
				check(bone >= 0, "leg bone")
				if bone >= 0:
					var before := skeleton.get_bone_pose_rotation(bone)
					ap.advance(0.3)
					check(not before.is_equal_approx(skeleton.get_bone_pose_rotation(bone)), "leg animated in walk")
			ModularCharacter.play_motion(ap, 6.0, false)
			check(ap.current_animation == "run", "run selected")
			ModularCharacter.play_motion(ap, 6.0, true)
			check(ap.current_animation == "idle", "frozen stops locomotion")
		visual.free()
	check(outfits.size() == 12, "12 distinct presets")
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	for child in game.get_children():
		if child is CharacterBase:
			child.set_physics_process(false)
	# Deriva da constante do jogo: o numero acompanha o tamanho do mapa.
	var expected_civilians: int = load("res://scripts/main.gd").CIVILIAN_COUNT
	check(get_nodes_in_group("civilians").size() == expected_civilians, "%d civilians spawned" % expected_civilians)
	check(get_nodes_in_group("thieves").size() == 7, "player + 6 thief bots")
	check(get_nodes_in_group("police").size() == 3, "3 police spawned")
	for child in game.get_children():
		if child is CharacterBase:
			check(child.current_model != null and child.current_model.name == "ModularVisual", "shared modular renderer: " + child.name)
	var player: CharacterBase = game.player
	var npc: CharacterBase = get_nodes_in_group("civilians")[0]
	var next_npc: CharacterBase = get_nodes_in_group("civilians")[1]
	var npc_outfit := npc.character_outfit.duplicate(true)
	# Put just these NPCs within disguise range; use the real gameplay action.
	for n in get_nodes_in_group("civilians"):
		n.position = Vector3(30, 0, 30)
	npc.position = player.position + Vector3(1, 0, 0)
	player._take_npc_outfit()
	check(player.character_outfit == npc_outfit, "disguise copies every appearance field")
	check(npc.stolen and npc.frozen, "victim knocked out")
	check(not npc.is_in_group("civilians"), "victim removed from crowd")
	check(player.motion_player != null and player.motion_player.has_animation("run"), "disguise retains rig and motion")
	check(not npc.current_model.find_child("Glasses", true, false).visible, "undressed has no glasses")
	next_npc.position = player.position + Vector3(-1, 0, 0)
	player._take_npc_outfit()
	check(not npc.stolen and not npc.frozen and npc.is_in_group("civilians"), "previous victim restored")
	check(npc.character_outfit == npc_outfit, "restored original outfit")
	player.become_police()
	check(player.character_outfit["skin"] == next_npc.character_outfit["skin"], "conversion preserves skin")
	check(not next_npc.stolen, "conversion restores disguise victim")
	check(player.is_in_group("police") and not player.is_in_group("thieves"), "conversion changes teams")
	check(player.current_model.find_child("PoliceCap", true, false).visible, "conversion shows police uniform")
	check(player.motion_player.has_animation("idle"), "converted player retains animation")
	var bot: CharacterBase = get_nodes_in_group("thieves")[0]
	var previous_police := get_nodes_in_group("police").size()
	game._convert_thief(bot)
	await process_frame
	check(get_nodes_in_group("police").size() == previous_police + 1, "bot conversion adds animated officer")
	# Andar x correr: a acao precisa existir e as duas velocidades precisam cair
	# em lados opostos do limiar de animacao (3.5 em ModularCharacter.play_motion),
	# senao o boneco corre andando ou anda correndo.
	var PlayerCls = load("res://scripts/player.gd")
	check(InputMap.has_action("run"), "acao 'run' existe no InputMap")
	check(PlayerCls.WALK_SPEED < 3.5, "andar fica abaixo do limiar de corrida")
	check(PlayerCls.RUN_SPEED >= 3.5, "correr fica acima do limiar de corrida")
	check(PlayerCls.WALK_SPEED < PlayerCls.RUN_SPEED, "correr e mais rapido que andar")
	print("CHARACTER_TESTS checks=", checks, " failures=", failures.size())
	# Este teste dispara o alerta, e alarm.ogg e mais longo que a janela de
	# espera usada nos outros. Em vez de dormir um tempo arbitrario, silencia os
	# one-shots de forma deterministica antes de destruir a cena — senao o
	# recurso de audio vaza e o runner reprova por erro de motor.
	for node in game.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	for node in game.find_children("*", "AudioStreamPlayer3D", true, false):
		node.stop()
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
