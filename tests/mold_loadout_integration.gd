extends SceneTree

# Matriz do bolso de moldes: saneamento/persistencia da escolha, geometria da
# roda e o comportamento dela em jogo (abre, escolhe, cancela, nao abre onde
# nao deve). Cada cenario e um caso, nao so o caminho feliz.

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 12:
			push_error(label)

func _initialize() -> void:
	run.call_deferred()

func press_right(player) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	player._unhandled_input(event)

func release_right(player) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = false
	player._unhandled_input(event)

func drag(player, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	player._unhandled_input(event)

func run() -> void:
	# --- Saneamento: o que vem de disco ou da tela nunca e usado cru ---------
	check(MoldLoadout.sanitize(["crate", "vase", "bush"]) == ["crate", "vase", "bush"], "escolha valida preservada")
	check(MoldLoadout.sanitize([]).size() == MoldLoadout.SLOTS, "vazio completa com o padrao")
	check(MoldLoadout.sanitize(["crate", "crate", "crate"]).size() == MoldLoadout.SLOTS, "repetido nao ocupa duas vagas")
	check(not MoldLoadout.sanitize(["crate", "crate"]).has(""), "completar nao insere tipo vazio")
	check(MoldLoadout.sanitize(["tire", "trash_bag"]).size() == MoldLoadout.SLOTS, "tipo inexistente descartado")
	for name in MoldLoadout.sanitize(["tire", 7, null, "vase"]):
		check(CityBuilder.PROP_TYPES.has(name), "todo molde salvo existe no cenario")
	check(MoldLoadout.sanitize(["crate", "vase", "bush", "cone", "barrel"]).size() == MoldLoadout.SLOTS, "excesso truncado")
	check(MoldLoadout.sanitize("nao e lista").size() == MoldLoadout.SLOTS, "entrada nao-lista nao quebra")
	check(MoldLoadout.sanitize(MoldLoadout.DEFAULT) == MoldLoadout.DEFAULT, "padrao e valido")

	# --- Persistencia -------------------------------------------------------
	var original := MoldLoadout.selected()
	check(MoldLoadout.save(["vase", "cone", "rock"]) == OK, "salvou o bolso")
	MoldLoadout.chosen.clear()
	check(MoldLoadout.selected() == ["vase", "cone", "rock"], "bolso volta do disco igual")
	check(MoldLoadout.starting_mold() == "vase", "molde inicial e o primeiro do bolso")

	# --- Roda: composicao das entradas --------------------------------------
	check(MoldLoadout.wheel_entries("") == ["vase", "cone", "rock"], "sem copia a roda e o bolso")
	check(MoldLoadout.wheel_entries("vase") == ["vase", "cone", "rock"], "molde do bolso nao duplica")
	var mixed := MoldLoadout.wheel_entries("barrel")
	check(mixed.size() == MoldLoadout.SLOTS + 1 and mixed.back() == "barrel", "molde copiado na rua entra na roda")

	# --- Roda: geometria ----------------------------------------------------
	check(MoldLoadout.sector_at(Vector2.ZERO, 3) == -1, "centro nao escolhe nada")
	check(MoldLoadout.sector_at(Vector2(0, -MoldLoadout.DEAD_ZONE * 0.5), 3) == -1, "dentro do raio morto nao escolhe")
	check(MoldLoadout.sector_at(Vector2(0, -200), 3) == 0, "para cima escolhe o primeiro")
	check(MoldLoadout.sector_at(Vector2(0, -200), 0) == -1, "roda vazia nao escolhe")
	for count in [2, 3, 4, 5, 6, 7]:
		for index in count:
			var direction := MoldLoadout.sector_direction(index, count)
			check(MoldLoadout.sector_at(direction * 180.0, count) == index, "setor %d de %d fecha com o desenho" % [index, count])
			# Meio caminho entre dois setores ainda cai em um deles, nunca fora.
			var between := (direction + MoldLoadout.sector_direction((index + 1) % count, count)).normalized() * 180.0
			var picked := MoldLoadout.sector_at(between, count)
			check(picked >= 0 and picked < count, "fronteira entre setores continua valida")

	# --- Em jogo ------------------------------------------------------------
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	for child in game.get_children():
		child.set_physics_process(false)
	var player = game.player
	await physics_frame
	await physics_frame

	check(player.copied_prop_type == "vase", "jogador nasce com o molde do bolso equipado")
	check(game.can_start_placement(player, "decoy"), "da para colocar isca sem copiar nada antes")

	# Cenario 1: abre, escolhe o segundo setor e solta -> troca o molde.
	press_right(player)
	check(player.wheel_open, "botao direito abre a roda")
	check(game.hud.mold_wheel.visible, "roda aparece na HUD")
	drag(player, MoldLoadout.sector_direction(1, player.wheel_entries.size()) * 200.0)
	check(player.wheel_index == 1, "arrastar escolhe o setor")
	release_right(player)
	check(not player.wheel_open and not game.hud.mold_wheel.visible, "soltar fecha a roda")
	check(player.copied_prop_type == "cone", "molde trocado pelo setor escolhido")

	# Cenario 2: solta sem sair do centro -> mantem o molde.
	press_right(player)
	drag(player, Vector2(0, -MoldLoadout.DEAD_ZONE * 0.4))
	release_right(player)
	check(player.copied_prop_type == "cone", "soltar no centro nao troca nada")

	# Cenario 3: Esc cancela mesmo com um setor apontado.
	press_right(player)
	drag(player, MoldLoadout.sector_direction(2, player.wheel_entries.size()) * 200.0)
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	player._unhandled_input(cancel)
	check(not player.wheel_open, "esc fecha a roda")
	check(player.copied_prop_type == "cone", "esc nao troca o molde")

	# Cenario 4: a roda nao rouba o botao direito de quem esta colocando isca.
	player._toggle_placement("decoy")
	check(player.placement_mode == "decoy", "modo de colocacao ligado")
	press_right(player)
	check(not player.wheel_open, "com isca na mao o direito nao abre a roda")
	release_right(player)
	check(player.placement_mode == "", "com isca na mao o direito cancela, como antes")

	# Cenario 5: abrir a roda e entao colocar isca fecha a roda.
	press_right(player)
	player._toggle_placement("decoy")
	check(not player.wheel_open and not game.hud.mold_wheel.visible, "entrar em colocacao fecha a roda")
	player._exit_placement()

	# Cenario 6: convertido em policial, a roda nao abre.
	player.become_police()
	press_right(player)
	check(not player.wheel_open, "policial nao tem roda de moldes")

	# Nada do bolso some do cenario: todo molde e construivel.
	for prop_type in MoldLoadout.catalog():
		var prop := CityBuilder.create_prop(prop_type)
		check(prop != null and String(prop.get_meta("prop_type")) == prop_type, "molde %s construivel" % prop_type)
		check(PropLabels.of(prop_type) == PropLabels.of(prop_type).to_upper(), "rotulo de %s em caixa alta" % prop_type)
		check(not PropLabels.of(prop_type).is_empty(), "rotulo de %s existe" % prop_type)
		prop.free()

	# Restaura o bolso do jogador: o teste nao pode mexer na config dele.
	MoldLoadout.save(original)
	print("MOLD_LOADOUT_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
