extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	var buildings := get_nodes_in_group("city_buildings")
	# 20/09: o quarteirao deixou de ter 4 predios soltos e virou um ANEL com
	# patio e beco. A conta vem das constantes, para nao voltar a ficar presa a
	# uma escala (antes era o literal 56).
	var per_block := CityBuilder._ring_offsets(CityBuilder.BLOCK_HALF).size() * 2
	per_block += CityBuilder._ring_offsets(CityBuilder.BLOCK_HALF - CityBuilder.RING_STEP).size() * 2
	per_block -= 1   # vao de entrada do beco
	var block_lots := 0
	for lx in CityBuilder.LOTS:
		for lz in CityBuilder.LOTS:
			if CityBuilder._lot_kind(Vector3(lx, 0, lz)) == "block":
				block_lots += 1
	check(buildings.size() == block_lots * per_block, "anel completo de predios em cada quarteirao")
	check(get_nodes_in_group("backdrop_buildings").size() > 0, "borda da cidade fechada por predios de fundo")
	var boxes: Array[AABB] = []
	for building in buildings:
		var door = building.find_child("Door", true, false)
		check(door != null and door.mesh.size.y >= 2.4, "door must fit a standing character")
		var box := ModelLibrary.combined_aabb(building, building.global_transform)
		boxes.append(box)
		check(box.size.y >= 6.4, "residential floor scale")
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			check(not boxes[i].intersects(boxes[j]), "neighboring facades cannot overlap")
	var labels := {}
	var atms := 0
	for target in get_nodes_in_group("robbable"):
		if target.get_meta("kind", "") == "store":
			labels[target.get_meta("label")] = true
			check(target.global_position.y < 0.2, "shop destination must be at walking level")
		if target.get_meta("kind", "") == "atm":
			atms += 1
	check(labels.size() == 6, "six different robbable stores")
	check(atms == 6, "six ATMs retained")
	print("CITY_SCALE_TESTS checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
