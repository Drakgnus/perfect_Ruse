extends SceneTree
# Mede quanto da RUA aceita esconderijo. Se a regra de colisao estiver estrita
# demais, o ladrao fica sem lugar para esconder.
const CityBuilder = preload("res://scripts/city_builder.gd")
func _initialize() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for f in 10:
		await process_frame
	var on_road := 0
	var valid := 0
	var first_valid := Vector3.ZERO
	for r in CityBuilder.ROADS:
		for step in 60:
			var t: float = -CityBuilder.MAP_HALF + step * (2.0 * CityBuilder.MAP_HALF / 60.0)
			for off in [-2.0, 0.0, 2.0]:
				var p := Vector3(t, 0.0, r + off)
				on_road += 1
				if game.is_placement_position_valid(p):
					valid += 1
					if first_valid == Vector3.ZERO:
						first_valid = p
	print("PLACEMENT_COVERAGE amostras=%d validas=%d (%.1f%%) primeiro_valido=(%.1f, %.1f)" % [on_road, valid, 100.0 * valid / maxf(1, on_road), first_valid.x, first_valid.z])
	print("CENTRO (3,2) valido=%s" % game.is_placement_position_valid(Vector3(3, 0, 2)))
	for node in game.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	await process_frame
	game.queue_free()
	await process_frame
	quit(0)
