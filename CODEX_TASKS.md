> Continuação atual: [handoff para o Claude](docs/CLAUDE_HANDOFF.md). Issue #2 implementada; avaliação de gameplay e lançamento nas issues #10–#15.

> Atualização 21/09/2026: este arquivo é histórico. O pedido atual e a próxima sequência estão em [docs/BACKLOG.md](docs/BACKLOG.md) e [docs/URBAN_GAMEPLAY_PLAN.md](docs/URBAN_GAMEPLAY_PLAN.md). A evolução visual solicitada será validada com o personagem chibi; as restrições artísticas antigas não substituem esse pedido. Nenhuma proposta nova foi implementada ainda.

# Perfect Ruse — Backlog para o Codex



Atualizado: 2026-07-15 (Claude)



## Contexto rápido da arquitetura (leia antes de qualquer tarefa)



- `scripts/main.gd` — **GameManager**: toda regra de partida (meta, alertas, suspeita, revista, prisão/conversão, esconderijos). Personagens **pedem**, o manager **decide**. Não duplique regra fora dele.

- `scripts/palette.gd` — paleta única (low poly stylized, cores chapadas). **REGRA: todo objeto/cor novo vem daqui.** Consistência visual é mecânica de gameplay: o dinheiro camuflado só engana se nada destoar.

- `scripts/city_builder.gd` — cenário e a fábrica `create_prop()` (usada TANTO pelos objetos do cenário quanto pelos esconderijos — por definição são idênticos).

- `scripts/character_base.gd` — base de todos os personagens (frozen, suspeita, marca de revistado).

- `scripts/player.gd`, `thief_bot.gd`, `npc.gd`, `police.gd`, `hud.gd` — papéis individuais.

- Validação: `Godot_v4.7 --headless --path . --import` e depois `--quit-after 1200` deve terminar **sem SCRIPT ERROR**.

- Fluxo de trabalho: uma tarefa por vez, tocando SÓ os arquivos listados na fronteira. Se precisar mudar `main.gd`, descreva a mudança no PR/resumo para revisão.



---



## T1 — Integração de assets low poly ✅ FEITO (Claude, 2026-07-15)



Já integrado. Modelos Kenney CC0 em `assets/models/` (ver `assets/CREDITS.md`):

- Props camufláveis: barril, caixa, vaso, **rocha** (era pneu), **tronco** (era saco de lixo), cone, arbusto.

- Prédios (City Kit Commercial) + toldos; loja/ATM ainda são primitivos com Label3D.

- `scripts/model_library.gd` carrega os GLB e ajusta escala pela AABB (props por maior dimensão, prédios por altura); `create_prop()` usa o modelo com **fallback** para primitivo se faltar.

- Texturas Kenney: cada pack tem seu `colormap.png` próprio (city e survival são DIFERENTES) → mantidos em subpastas separadas (`city/Textures`, `survival/Textures`); cone/vaso/arbusto embutem textura no GLB.

- **Gotcha de import**: após adicionar GLB novo, rodar `Godot --headless --path . --import` antes de usar. Se der erro `Can't open .../Textures/colormap.png`, o modelo referencia colormap externo — coloque o colormap do pack correto na subpasta.



### T1b — Polimento visual restante (PRIORIDADE MÉDIA, para o Codex)

- Trocar loja e ATM (hoje caixas primitivas) por modelos: Kenney City Kit Commercial tem fachadas; ou usar `detail-awning` + um modelo de vitrine.

- Adicionar variedade: mais tipos de prédio nos fundos, árvores (`assets/models/tree.glb` já baixado, ainda não instanciado no cenário — usar em `_add_street_furniture`).

- Personagens ainda são cápsulas (`character_base.gd build_body`). Opcional: modelos humanoides low poly Kenney (`Blocky Characters`), MAS mantendo civis e ladrões visualmente IDÊNTICOS (regra da camuflagem). Ladrão que troca de roupa (F) copia a cor/skin do NPC.

- Regra mantida: props camufláveis sem animação; mesmo estilo Kenney em tudo.



## T2 — Áudio (PRIORIDADE ALTA)



- Fontes: Kenney (Audio packs, CC0).

- Eventos que precisam de som: roubo concluído, alerta disparado, paralisação/revista, prisão/conversão, esconder dinheiro, resgatar dinheiro, vitória/derrota, passos (opcional).

- Onde mexer: novo `scripts/audio_manager.gd` (autoload ou filho do main) com API `play(event_name)`; chamadas pontuais no `main.gd` (uma linha por evento — marcar com comentário `# audio`).

- Aceite: headless sem erros; sons não sobrepostos de forma estridente (limitar repetição do alerta).



## T3 — Habilidades dos ladrões ✅ FEITO (Claude, 2026-07-15)



`scripts/abilities.gd` com 6 habilidades (tecla G p/ as ativas, cooldown na HUD):

- Passivas: Especialista em Furtos (canaliza -40%), Batedor de Carteiras (+50% NPC), Contrabandista (suspeita mais lenta), Camuflador (dobro de iscas).

- Ativas: Hackeador (alarme falso região aleatória), Informante (revela policiais 6s).

- Atribuída aleatoriamente no spawn (player e bots). **Pendência p/ Codex**: os BOTS não usam habilidades ATIVAS (só passivas se aplicam). Adicionar IA simples de uso de habilidade ativa nos bots (`thief_bot.gd`, chamar `game.use_ability(self)` com heurística).



## T4 — Menu inicial ✅ FEITO (Claude, 2026-07-15)



`scenes/menu.tscn` + `scripts/menu.gd` (título, conceito, controles, Jogar/Sair). `run/main_scene` aponta pro menu. Overlay de fim já mostra resumo (roubado/recuperado/conversões/duração).

- **Pendência p/ Codex**: tela de fim poderia ter botão "Voltar ao menu" (hoje só Enter reinicia a partida); menu poderia ter seleção de habilidade inicial em vez de aleatória.



## T5 — POC Multiplayer (PESQUISA — branch separada, não mexer no main)



- O GDD é multiplayer (16 ladrões x 4 policiais). Pesquisar e prototipar em branch `poc-multiplayer`: high-level multiplayer do Godot (ENet), `MultiplayerSpawner`/`MultiplayerSynchronizer`, autoridade do servidor para as decisões do GameManager.

- Entregável: documento curto `docs/MULTIPLAYER_POC.md` + protótipo com 2 clientes locais movendo personagens sincronizados. NÃO precisa das mecânicas ainda.

- Atenção de design para o futuro: o marcador **$** do dinheiro escondido (`MoneyMarker` em `main.gd`) deve ser visível SOMENTE para o time dos ladrões; iscas e objetos colocados devem ser indistinguíveis para os policiais.



## T7 — Cidade/stealth/mapa ✅ FEITO (Claude, 2026-07-15)



- Cidade em GRID (~90x90, `CityBuilder.ROADS`/`LOTS`/`MAP_HALF`), 16 lotes com prédios, lojas e ATMs distribuídos.

- **Carros** Kenney (`assets/models/cars/`) estacionados nas ruas como alvo roubável (kind "car", R$180, 3.5s). Loja subiu p/ 7s / R$450 (mais demorada, com barra de canalização).

- **Linha de visão** (`main.seeing_officer`/`check_robbery_vision`): roubo é bloqueado + flagrante se um policial vê o ladrão (alcance 22, cone ~55°, raycast — NPCs e props servem de cobertura). Canalização é cancelada se um policial entra na visão.

- **Mini-mapa** (`scripts/minimap.gd`, canto sup. direito): ruas, jogador (seta), polícia (pontos vermelhos c/ direção), alerta (anel pulsante), alvos (loja amarela / carro branco / ATM azul), dinheiro escondido do time (dourado). Tecla **M** expande.

- Habilidade **Hackeador** virou interativa: G abre o mapa expandido em modo alvo → clique dispara alarme ancorado no alvo mais próximo.

- **Pendências p/ Codex**: viaturas de polícia paradas como decoração (`ModelLibrary.POLICE_CAR_MODEL` já baixado); indicador visual quando o PRÓPRIO jogador está sendo visto (ex.: contorno vermelho na tela / ícone de olho); minimap poderia mostrar cone de visão dos policiais; bots deveriam respeitar melhor a linha de visão ao decidir roubar (hoje só falham se vistos).



## T10 — Cidade densa + Blocky Characters ✅ FEITO (Claude, 2026-07-15)



- Quarteirões AGORA CHEIOS: cada lote recebe aglomerado 3x3 de prédios de alturas variadas (`_add_buildings_and_targets` + `_is_front_cell`), tapando a visão entre quadras (antes 1 prédio/lote deixava o mapa vazio).

- Fix de escala de CARRO: fitava pela altura (4.2m!) → agora fit pela maior dimensão (comprimento ~4.2, altura ~1.5).

- Personagens trocados de Mini (chibi) para **Blocky Characters** (18 skins, proporção humana, `assets/models/blocky/`, cada skin = textura própria `texture-X.png`). GOTCHA: blocky são RIGGADOS (skeleton) → fit por AABB QUEBRA (câmera presa dentro do player gigante); usar escala FIXA `CHARACTER_HEIGHT/CHARACTER_NATIVE_HEIGHT` (2.7). Altura 1.7m.

- Polícia = `b_r` + material azul SÓLIDO (`police_tint_material`, sem textura) — uniforme distinto.

- Pool filtrado para SÓ CIDADÃOS NORMAIS (10 skins: a,b,c,e,i,j,k,m,p,q). Excluídos zumbis (l,o), ninja (h), fantasias (d,f,g), quimono (n) — pedido do usuário "sem zumbi/super-herói".

- Mini Characters (`assets/models/characters/`) mantidos no repo mas fora do pool. Kenney "Modular Characters" é 2D (não serve p/ 3D).

- **Pendências p/ Codex**: escolher/confirmar qual blocky skin lê melhor como policial; possibilidade de fazer roupas novas repintando as texturas `blocky/Textures/texture-*.png` (sem Blender); montar mais variedade civil.



## T8 — Personagens humanoides + disfarce por roupa ✅ FEITO (Claude, 2026-07-15)



- Cápsulas trocadas por **Kenney Mini Characters** (`assets/models/characters/`, 12 modelos com roupas distintas). Escala ~1.5m dá referência real vs carros.

- Disfarce (F) agora copia o **modelo/roupa EXATO** do NPC (`character_base.set_character_model` + `player._take_npc_outfit`) — a roupa é o diferencial (pedido do usuário, estilo Rubber Bandits/Mecha Chameleon).

- Polícia usa modelo fixo (`POLICE_CHARACTER`) com tint azul (`police_tint_material`) + sirene. Conversão do jogador troca pro modelo azul.

- Civis/ladrões sorteiam modelo aleatório; `character_base` tem fallback de cápsula se faltar asset.



### T11 — Personagens Among Us / Mecha Chameleon ✅ FEITO (Claude, 2026-07-15)

- PROCEDURAL `scripts/character_style.gd`: HUMANOIDE com pernas, braços, torso, cabeça (estilo boneco Mecha Chameleon — NÃO é bean/Among Us; usuário corrigiu que quer pessoa com membros). Vestuário = cor camisa + calça + pele; ACESSÓRIO 3D destacado (cap/beanie/tophat/cowboy/police). ~20+ combos distintos.

- Disfarce (F) copia o OUTFIT (dict {body, hat, hat_color}) do NPC; `character_base.set_outfit`. Polícia = `CharacterStyle.police_outfit()` (corpo azul + boné com emblema dourado) + sirene.

- Carros: freiam por pedestre à frente (`traffic_car._pedestrian_ahead`) e semáforo tem AMARELO (`light_sub` green/yellow no main).

- `ModelLibrary` character/blocky agora sem uso (assets em disco, harmless). Pode limpar depois.

- Pendência p/ Codex: mais tipos de acessório (óculos, mochila, cabelo); talvez importar acessórios 3D reais (Kenney Mini Characters tem glasses/mask/sunglasses soltos) por cima da base.



### T11-OLD — visão original (referência)

- Base humanoide LISA (não quadrada/Minecraft). Os Blocky atuais são placeholder.

- **Acessórios devem ser objetos 3D que SOBRESSAEM** (chapéu, óculos, mochila, boné) — NÃO pintados na textura (crítica do usuário ao Minecraft). Identidade = acessórios 3D + cor, estilo Among Us.

- Precisa ~20 variações distintas (senão fica difícil distinguir NPCs / verificar).

- Disfarce copia base + acessórios. Abordagem sugerida: corpo procedural liso (cápsula/bean) em ~20 cores + 1-2 acessórios 3D combináveis (a lib Kenney Mini Characters TEM acessórios soltos: glasses/mask/sunglasses).



### T9 — Carros dirigindo + semáforos ✅ FEITO (Claude, 2026-07-15)

- `scripts/traffic_car.gd`: 8 carros dirigem pelas ruas do grid, param no vermelho, viram ROUBÁVEIS quando parados (saem do grupo ao andar). Loop nas bordas.

- Semáforos: ciclo global `x_traffic_green` (alterna a cada 9s) em `main`; postes com luz verde/vermelha nos cruzamentos (`_spawn_traffic_lights`); `is_axis_green(is_x)`.

- CÂMERA: com prédios densos a câmera 3ª pessoa entrava nos prédios. SpringArm3D deu dor de cabeça (ordem de rotação Euler) → usei COLISÃO MANUAL por raycast (`player._update_camera_collision`, mask=4). Prédios em `collision_layer = 1|4` (camada 3 = bloqueia câmera). Spawn do player movido pro cruzamento central (0,0,0).

- Pendência p/ Codex: carros deveriam frear/desviar de pedestres (hoje passam por cima); semáforo poderia ter amarelo.

- Alguns carros devem **andar pelas ruas** do grid e **parar em semáforos/cruzamentos**; quando parados, viram alvo roubável (como hoje os estacionados).

- Sugestão: `scripts/traffic_car.gd` (CharacterBody3D ou Path following as ruas em `CityBuilder.ROADS`), estado dirigindo/parado; semáforos simples nos cruzamentos alternando em ciclo; ao parar, add ao grupo "robbable" (remover ao andar). Cuidado com a linha de visão (roubo em carro parado também respeita `check_robbery_vision`).

- Ver `ModelLibrary.CAR_MODELS`. Manter colisão para não atropelar pedestres (ou parar ao detectar).



## T12 — Nervosismo por dinheiro + disfarce rouba-identidade ✅ FEITO (Claude, 2026-07-15)

- NERVOSISMO agora vem de CARREGAR muito dinheiro por muito tempo (não de ficar sem roubar — isso não fazia sentido). `main`: acima de MONEY_NERVOUS_THRESHOLD(300) sobe (NERVOUS_RATE); esconder/trocar de roupa alivia (CLOTHES_RELIEF). Ladrão treme/sua quando o nervosismo passa de ~40% → pista p/ polícia humana. Empurra o uso da mecânica de esconder.

- DISFARCE = roubar identidade: F derruba o NPC (npc.knock_out: sai dos grupos, cai, some em ~3s), jogador assume a roupa; NÃO existem dois iguais; ao trocar de novo, a vítima anterior VOLTA (restore). `player.disguise_victim`.

- Pendência p/ Codex: (1) tirar o ATALHO da IA policial que lê suspicion como número (deve depender só da observação/tremor p/ ser coerente com polícia humana); (2) NPCs reagirem a suspeito muito nervoso (delação); (3) rendimento decrescente por roubar o mesmo alvo (anti-camping); (4) mais tells (olhar em volta).



## T6 — Juice/feedback visual (baixa prioridade)



- Bob de caminhada nos personagens, flash na paralisação, partícula simples na prisão/conversão, fumacinha ao esconder dinheiro. Tudo dentro da paleta (`palette.gd`) e sem contornos/toon shader.



---



## O que NÃO fazer



- Não introduzir texturas realistas/PBR nem toon shader com contornos (decisão de direção de arte registrada).

- Não dar animação aos props camufláveis.

- Não mover decisões de regra para os personagens — sempre via `main.gd`.

- Não commitar a pasta `.godot/`.





## Estado atual dos personagens ? 19/09/2026



As descri??es de c?psulas/CharacterStyle procedural e integra??o restrita ao jogador acima s?o hist?ricas. A renderiza??o atual usa `ModularCharacter` com `citizen.glb` e o rig/clipes do corpo chibi do autor, compartilhados por todos os pap?is. `CharacterStyle` fornece o cat?logo e apar?ncia; F continua copiando os dados e agora mant?m o mesmo visual animado. Menu possui seletor com pr?via; policial possui uniforme reservado. 40 civis povoam a cidade. Fonte, instru??es, limita??es e valida??o: `docs/CHARACTERS_MODULAR.md`. N?o alterar regras de partida ao evoluir o visual.





## C11 — Bloco 2: colocação e iscas (20/09/2026)



Preparação de 0,8 s com anel, cancelamento sem débito, validação final de espaço, assentamento visual e efeitos. Polícia humana/IA destrói iscas ao concluir inspeção; lojas mantêm grupo de roubo e cooldown. Preservado Bloco 1 do Claude. Corrigido timer de revelação e runner que ignorava erros do motor. 175 + 56 + 41 verificações, 1.200 frames, 54 amostras de carros e smoke gráfico aprovados. Detalhes, limites, comandos e tentativas: `docs/PLACEMENT_AND_DECOYS.md`. Exceção autorizada à regra antiga de props imóveis: somente animação breve de assentamento; colisão permanece fixa. Sem commit; playtest manual pendente.



## C12 - Cidade integrada, rotas, pausa e props livres (20/09/2026)

Concluido sobre a cidade 144x144 mais recente do Claude: 64 civis, 14 carros, assets, praca e bosque preservados. Novos controles: Esc pausa/menu/sair; R escolhe destino no mapa com camera livre; roda gira prop, Shift+roda troca face e V move isca propria. Sobreposicao permitida e apoio em paredes/tetos. Calcadas com rampas e travessias, destinos de lojas/ATMs, vagas separadas e movimento fisico dos carros. Validacao, limites, tentativas e imagens em `docs/CITY_AND_CONTROLS.md`. As restricoes de rua/altura/espacamento de C11 foram substituidas por pedido explicito do autor. Sem commit.


## C13 — Escala urbana e fachadas (20/09/2026)
Implementado: parcelas maiores, portas de 2,5 m, 56 edifícios, seis comércios com vitrines e toldos, varandas/telhados e batching estático. Evidência, limitações e prevenção: `docs/CITY_SCALE.md`. Capturas: `docs/city-scale-shop.png` e `docs/city-scale-street.png`.
