> Atualização 21/09/2026: este arquivo é histórico. O pedido atual e a próxima sequência estão em [docs/BACKLOG.md](docs/BACKLOG.md) e [docs/URBAN_GAMEPLAY_PLAN.md](docs/URBAN_GAMEPLAY_PLAN.md). A evolução visual solicitada será validada com o personagem chibi; as restrições artísticas antigas não substituem esse pedido. Nenhuma proposta nova foi implementada ainda.

# Fila de trabalho do CODEX (uma tarefa por vez, em ordem)



Gerenciado por Claude. Pegue **a próxima tarefa não concluída**, implemente SÓ ela,

valide (`Godot_v4.7 --headless --path . --import` e depois `--quit-after 1200` SEM

SCRIPT ERROR) e marque como ✅. Não pule a ordem. Leia `CODEX_TASKS.md` (contexto de

arquitetura) antes. Regras gerais: decisão de regra só no `main.gd`; personagens

procedurais em `character_style.gd`; validar headless; não commitar `.godot/`.



Variáveis de nó vindas de `get_nodes_in_group` são untyped → declare tipo explícito

(`var x: Vector3 = ...`) senão dá "Cannot infer type". `direct_space_state`/raycast só

em `_physics_process`. Após criar `class_name` novo, rodar `--import` antes de usar.



---



## C0 — NPC roubado aparece SEM ROUPA (de cueca) ✅ FEITO

**Contexto:** o disfarce já está pronto — F derruba o NPC (`npc.knock_out`), o jogador

assume a roupa dele, e o NPC some em ~3s e volta ao trocar de roupa de novo (`restore`).

**Faltou:** como o ladrão LEVOU a roupa, o NPC caído deve aparecer **sem roupa (só de

cueca)** enquanto está no chão.

**Fazer:**

- Em `character_style.gd`, criar `build_underwear(holder, outfit, height)`: mesmo corpo

  humanoide (pernas/braços/torso/cabeça em cor de PELE do outfit) mas SEM camisa/calça

  coloridas e SEM acessório — apenas uma cueca/short simples (um box/faixa escura na

  cintura). Reutilizar os helpers `_capsule/_sphere/_box`.

- Em `npc.knock_out()`: reconstruir o visual chamando a versão "sem roupa"

  (trocar o conteúdo de `visual_holder` — pode usar um `set_undressed()` novo no

  `character_base` que faz `_swap_visual` com `CharacterStyle.build_underwear`).

- Em `npc.restore()`: reconstruir a roupa normal (`set_outfit(character_outfit)` já faz

  isso — garantir que restore volte vestido).

**Aceite:** headless sem erro; ao apertar F num NPC, ele cai visivelmente DE CUECA antes

de sumir; ao voltar (quando o ladrão troca de roupa), está vestido de novo.

**Não fazer:** não mudar a lógica de knock_out/restore/nervosismo — só o visual do estado caído.



## C1 — Tirar o "atalho" da IA policial (coerência com polícia humana) ✅ FEITO

**Problema:** `police.gd` (`_pick_suspect`, `SUSPICION_APPROACH_THRESHOLD`) escolhe alvo

lendo `suspicion` como número. Isso não existe quando o policial é humano — ele só vê

o TREMOR. O bot deve depender do observável.

**Fazer:** em `police.gd`, trocar a seleção de suspeito por um critério observável:

só considerar suspeito quem está **tremendo** (nervosismo alto) E dentro do campo de

visão do policial (reusar a lógica de cone/linha de visão de `main.seeing_officer`,

extrair para um helper reutilizável se preciso) OU quem está claramente fugindo/carregando.

Remover o uso direto de `candidate.suspicion` como gatilho; usar um limiar de nervosismo

que corresponda ao ponto em que o tremor começa (~40%, ver `character_base._process`).

**Aceite:** headless sem erro; policial só persegue ladrão que estaria visivelmente

nervoso e à vista; ladrão tranquilo (pouco dinheiro) passa despercebido.

**Não fazer:** não mexer na mecânica de nervosismo em si (já pronta no `main`).



**Resumo:** a IA policial agora aborda somente suspeitos que consegue ver no cone, sem obstrução, e que exibem tremor, fogem claramente ou carregam dinheiro; não lê mais `suspicion` diretamente.



## C2 — Multidão delata o suspeito muito nervoso ✅ FEITO

**Fazer:** quando um ladrão está com nervosismo alto (>~70%), NPCs civis próximos

(~4m) reagem: viram-se para ele e recuam alguns passos (comportamento em `npc.gd`,

consultando ladrões do grupo "thieves" com suspeita alta). Opcional: um pequeno "!"

sobre o NPC que reage. Isso cria um foco de atenção que o policial HUMANO nota de longe,

substituindo o "sistema sabe".

**Aceite:** headless sem erro; ao deixar a suspeita estourar perto de civis, eles

visivelmente se afastam/olham.



**Resumo:** civis detectam ladrões muito nervosos (tremor visível e suspeita ≥70) a até 4 m, olham para eles e recuam por alguns passos antes de voltar à rotina.



## C3 — Rendimento decrescente por alvo repetido (anti-camping) ✅ FEITO

**Fazer:** roubar o MESMO alvo (ou o mesmo TIPO: npc/car/store/atm) em sequência rende

cada vez menos, recuperando com o tempo. Implementar em `main.gd` (onde `rob_npc`/

`rob_target` dão dinheiro): guardar um multiplicador por tipo que cai a cada roubo

(ex.: 1.0 → 0.7 → 0.5 …) e regenera devagar. Mostrar no toast o valor real recebido.

**Aceite:** headless sem erro; roubar 3x seguidas o mesmo tipo rende bem menos na 3ª.



**Resumo:** cada tipo de alvo (NPC, carro, loja ou ATM) agora tem um multiplicador de rendimento compartilhado que cai a 70% a cada roubo, tem piso de 35% e se recupera lentamente com o tempo; o toast mostra o valor efetivamente recebido.



## C4 — Mais "tells" de nervosismo (além de tremor/suor) ✅ FEITO

**Fazer:** em `character_base._process`, adicionar ao ladrão nervoso: olhar em volta

(pequena oscilação de yaw da cabeça/corpo) e andar levemente errático. Calibrar para ser

perceptível de PERTO, não gritante de longe. Não exagerar a amplitude.

**Aceite:** headless sem erro; nervosismo alto tem leitura clara mas justa.



**Resumo:** ladrões nervosos agora fazem uma varredura suave de olhar/corpo e exibem um discreto desvio lateral de passada durante o movimento; os dois efeitos crescem com o nervosismo e mantêm amplitude curta.



## C5 — Áudio (Kenney CC0) ✅ FEITO

**Fazer:** `scripts/audio_manager.gd` (filho do main) com `play(evento)`. Sons Kenney

(baixar de kenney.nl, packs de áudio CC0) para: roubo concluído, alarme, paralisar/revistar,

prisão/conversão, esconder $, resgatar $, vitória/derrota. Chamadas de 1 linha no `main`

marcadas com `# audio`. Limitar repetição do alarme.

**Aceite:** headless sem erro; eventos disparam som sem sobrepor estridente.



**Resumo:** efeitos CC0 do pack Interface Sounds do Kenney foram integrados em `assets/audio/`; `AudioManager` centraliza a reprodução, reduz volume e limita o alarme a uma vez por 1,2 s.



## C6 — Bots usam habilidades ativas + tela de fim "voltar ao menu" ✅ FEITO

**Fazer:** (a) `thief_bot.gd` chama `game.use_ability(self)` com heurística simples

(Hackeador/Informante quando um policial está perto). (b) overlay de fim (`hud.gd`)

ganha opção/instrução de voltar ao menu (`scenes/menu.tscn`) além do Enter=reiniciar.

**Aceite:** headless sem erro; bots disparam alarme às vezes; do fim dá pra voltar ao menu.



**Resumo:** bots Hackeador e Informante acionam a habilidade quando um policial fica a menos de 9 m; a tela de fim agora orienta Enter para reiniciar e Esc para voltar ao menu.



## C7 — Mais variedade de vestuário/acessórios ✅ FEITO

**Fazer:** em `character_style.gd`, adicionar acessórios (óculos, mochila, cabelo simples)

e mais cores/combos, mantendo o estilo humanoide liso. Garantir que o disfarce copie os

novos campos do outfit. Manter civis e polícia distintos.

**Aceite:** headless sem erro; nitidamente >20 combinações distintas.



**Resumo:** o outfit agora inclui cabelo, óculos e mochila/satchel 3D, cada qual com cores e tipos variados; o disfarce duplica todos esses campos, enquanto a versão de cueca remove todos os acessórios. A polícia preserva uniforme e boné exclusivos.



## C8 — POC Multiplayer (BRANCH SEPARADA `poc-multiplayer`, NÃO mexer no main) ✅ FEITO

**Fazer:** protótipo de rede alto-nível do Godot (ENet): `MultiplayerSpawner`/

`MultiplayerSynchronizer`, autoridade do servidor sobre as decisões do GameManager,

2 clientes locais com personagens sincronizados (movimento). Documento curto

`docs/MULTIPLAYER_POC.md`. NÃO precisa portar as mecânicas ainda — só provar a base.

**Atenção:** o marcador $ do dinheiro escondido e o tremor devem ser tratados por time

depois; suspeita/detecção 100% observacional (ver C1). Autoridade das regras no servidor.

**Aceite:** 2 clientes locais movem personagens sincronizados; doc escrito.



**Resumo:** POC isolado em `multiplayer_poc/` (o diretório não possui Git ativo) usa ENet na porta 7007, `MultiplayerSpawner` para criar jogadores e `MultiplayerSynchronizer` para replicar posição/rotação. O host é autoritativo: clientes enviam somente entrada validada pelo servidor. Instruções de teste estão em `docs/MULTIPLAYER_POC.md`.



## C9 — Carros nascendo dentro dos predios (bug reportado pelo usuario)

Problema: carros aparecem sobrepostos/dentro dos predios.

Contexto do grid (scripts/city_builder.gd): ROADS=[-24,0,24], ROAD_HALF=3.5,

LOTS=[-36,-12,12,36] (centros de quarteirao com predios+cluster offsets).

- Carros ESTACIONADOS: `_add_cars`/`_add_car` posicionam em t=[-33,-15,15,33] com offset

  perpendicular `ROAD_HALF+1.3` (=4.8) da rua -> caem na borda da quadra e batem no predio.

- Carros de TRANSITO: main.gd `_spawn_traffic` (linha ~137) — validar que o ponto inicial

  fica sobre a rua, nunca dentro de um quarteirao/predio.

Objetivo: nenhum carro deve nascer sobreposto a um predio. Pular/reposicionar carros cujo

footprint (2.0 x 4.2) colida com o footprint de um predio. Manter carros sobre a faixa de

rua/estacionamento. Validar com `--import` + rodar sem SCRIPT ERROR. NAO mexer em outra coisa.

STATUS: FEITO





## C10 ? Personagens modulares animados (19/09/2026) ? IMPLEMENTADO, VALIDADO LOCALMENTE



Pedido direto do autor: terminar personagens com acess?rios combin?veis, anima??es e policial, com popula??o suficiente. Substitu?da a renderiza??o de jogador/civis/bots/pol?cia por base chibi compartilhada, 12 presets, seletor, 40 civis e clipes idle/walk/run. F e convers?o preservam o sistema modular. 175 + 56 verifica??es passaram; 1200 frames headless; smoke gr?fico 60 FPS na amostra local. Fonte Blender, imagens, limites, tentativas e comandos em `docs/CHARACTERS_MODULAR.md`. Aprova??o visual/playtest do autor pendentes; sem commit. Modelos anteriores preservados.





## C11 — Bloco 2: colocação e iscas (20/09/2026)



Preparação de 0,8 s com anel, cancelamento sem débito, validação final de espaço, assentamento visual e efeitos. Polícia humana/IA destrói iscas ao concluir inspeção; lojas mantêm grupo de roubo e cooldown. Preservado Bloco 1 do Claude. Corrigido timer de revelação e runner que ignorava erros do motor. 175 + 56 + 41 verificações, 1.200 frames, 54 amostras de carros e smoke gráfico aprovados. Detalhes, limites, comandos e tentativas: `docs/PLACEMENT_AND_DECOYS.md`. Exceção autorizada à regra antiga de props imóveis: somente animação breve de assentamento; colisão permanece fixa. Sem commit; playtest manual pendente.



## C12 - Cidade integrada, rotas, pausa e props livres (20/09/2026)

Concluido sobre a cidade 144x144 mais recente do Claude: 64 civis, 14 carros, assets, praca e bosque preservados. Novos controles: Esc pausa/menu/sair; R escolhe destino no mapa com camera livre; roda gira prop, Shift+roda troca face e V move isca propria. Sobreposicao permitida e apoio em paredes/tetos. Calcadas com rampas e travessias, destinos de lojas/ATMs, vagas separadas e movimento fisico dos carros. Validacao, limites, tentativas e imagens em `docs/CITY_AND_CONTROLS.md`. As restricoes de rua/altura/espacamento de C11 foram substituidas por pedido explicito do autor. Sem commit.


## C13 entregue — Escala e cidade
CityBuilder agora constrói fachadas em medidas de gameplay, sem reduzir portas para caber no lote. Seis lojas e seis ATMs preservados. Consultar `docs/CITY_SCALE.md` antes de alterar layout; preservar teste de volumes, caminhos e trânsito. Não foram alterados personagens, iscas, controles ou assets de Claude.

## C14 entregue — Quadra em anel, beco e limite da cidade (20/09/2026, Claude)
`ROAD_SPACING` 36 -> 64: quadra de 47 m, mapa 256 m, anel de 15 predios por quarteirao (210 no total, eram 56), patio interno com props e um beco sem saida por quadra. Borda fechada com fileira de predios de fundo (grupo `backdrop_buildings`), barricadas nas bocas de rua e parede invisivel. Ler `docs/CITY_SCALE.md` antes de mexer em layout. Nao alterei personagens, iscas, habilidades nem audio. Sem commit; playtest do autor pendente.


## C15 entregue — Moldes de bolso e roda de selecao (20/09/2026, Claude)
O ladrao escolhe ate 3 moldes antes da partida (menu MOLDES DE BOLSO) e troca entre eles
segurando o botao direito na roda radial. Novos: `mold_loadout.gd`, `mold_wheel.gd`,
`mold_kit.gd`, `scenes/mold_kit.tscn`, `prop_labels.gd`, `tests/mold_loadout_integration.gd`.
O botao direito COM isca na mao continua cancelando a colocacao — nao mexer nisso sem
rodar o teste novo. Ler `docs/MOLD_LOADOUT.md` antes de alterar moldes, roda ou rotulos.
Nao alterei cidade, personagens, iscas, habilidades nem audio. Sem commit; playtest pendente.
