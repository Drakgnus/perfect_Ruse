extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene: Control = load("res://scenes/wardrobe.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	for hat in CharacterStyle.HEADWEAR:
		scene.outfit["hat"] = hat
		scene._refresh()
		var expected: String = ModularCharacter.HATS.get(hat, "")
		for mesh in scene.visual.find_children("*", "MeshInstance3D", true, false):
			if mesh.name in ModularCharacter.HATS.values():
				check(mesh.visible == (str(mesh.name) == expected), "hat exclusive: " + str(hat))
	for hair in ["short", "bob", "bun", "none"]:
		scene.outfit["hat"] = "none"
		scene.outfit["hair"] = hair
		scene._refresh()
		var wanted: String = {"short": "Hair", "bob": "HairBob", "bun": "HairBun"}.get(hair, "")
		for name in ["Hair", "HairBob", "HairBun"]:
			check(scene.visual.find_child(name, true, false).visible == (name == wanted), "hair toggle: " + hair)
	scene.outfit = CharacterStyle.preset(4)
	scene.motion = "run"
	scene._refresh()
	check(scene.anim.current_animation == "run", "preview run button")
	scene.preview_police = true
	scene._refresh()
	check(scene.visual.find_child("PoliceCap", true, false).visible, "preview police")
	check(scene.outfit["hat"] != "police", "police preview never changes civilian save")
	check(CharacterStyle.save_player_outfit(scene.outfit) == OK, "save appearance")
	var expected: Dictionary = scene.outfit.duplicate(true)
	CharacterStyle.selected_outfit = {}
	check(CharacterStyle.player_outfit() == expected, "reload appearance from disk")
	var nude := ModularCharacter.build(expected, true)
	root.add_child(nude)
	check(nude.find_child("FootL", true, false).visible, "bare feet for knocked-out victim")
	check(not nude.find_child("BootL", true, false).visible, "no shoes for knocked-out victim")
	check(not nude.find_child("Jacket", true, false).visible, "no jacket for knocked-out victim")
	nude.free()
	scene.queue_free()
	await process_frame
	print("WARDROBE_TESTS checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
