> Próxima evolução planejada em 21/09/2026: [bairro, perseguição e visual](URBAN_GAMEPLAY_PLAN.md). O texto abaixo documenta entregas anteriores; a proposta nova ainda não está implementada.

# Moldes de bolso e roda de seleção (20/09/2026)

Pedido do autor: o ladrão escolhe alguns moldes **antes** da partida e pode colocá-los durante o jogo; os demais continuam sendo copiados na rua. Na partida, o botão direito abre uma roda para trocar entre eles.

Implementação single-player. Não porta regras para o POC multiplayer.

## Como usar

1. No menu inicial, **MOLDES DE BOLSO** (ao lado de PERSONAGEM E ACESSÓRIOS).
2. Marque até 3 objetos entre os 7 do cenário. "Ver" mostra o objeto em 3D. O bolso nunca fica vazio e nunca passa de 3: o quarto clique é recusado com aviso, em vez de descartar silenciosamente o mais antigo.
3. SALVAR E VOLTAR grava em `user://molds.cfg`. A escolha vale para as próximas partidas.
4. Na partida o jogador **já nasce equipado** com o primeiro molde do bolso — antes ele era obrigado a achar um objeto na rua antes da primeira isca.
5. Segure o **botão direito** (sem isca na mão), mova o mouse na direção do molde e **solte** para trocar. Soltar perto do centro ou apertar Esc cancela sem trocar.
6. A tecla C continua copiando qualquer objeto da rua. O molde copiado entra na roda como setor extra, então a roda troca qualquer molde que o jogador tenha — inclusive o que acabou de copiar.

## Implementação

- `mold_loadout.gd` (`class_name MoldLoadout`): bolso, persistência, saneamento e geometria da roda. Tudo que vem de disco ou da tela passa por `sanitize()` — tipo inexistente, repetido ou sobrando é descartado e o que faltar é completado, então o bolso nunca sai com um tipo que o `CityBuilder` não sabe construir. `sector_at()` e `sector_direction()` são o mesmo par usado pelo desenho e pela escolha, para o setor clicado ser exatamente o desenhado.
- `mold_wheel.gd` (`class_name MoldWheel`): desenho por código, filho da HUD, escondido por padrão. Anel azul marca o molde já equipado; agulha mostra a direção acumulada; raio morto central de 42 px evita troca por tremor de mão.
- `mold_kit.gd` + `scenes/mold_kit.tscn`: tela de pré-partida, mesmo padrão do guarda-roupa (SubViewport com o prop real construído por `CityBuilder.create_prop`).
- `player.gd`: estado da roda, abertura/fechamento e escolha. A roda fecha sozinha ao entrar em colocação, ao ser preso/convertido, ao sair da fase de jogo e no Esc.
- `prop_labels.gd` (`class_name PropLabels`): nomes dos moldes, antes presos ao `main.gd`. O mapa antigo estava desatualizado: `rock` e `log` caíam no fallback em inglês e havia `tire`/`trash_bag`, que não existem mais no cenário.

## Decisões

- **O botão direito só abre a roda fora do modo de colocação.** Com isca na mão ele continua cancelando a colocação, como antes — o teste cobre os dois casos para essa função não ser roubada numa refatoração futura.
- **A roda do mouse não mudou.** Ela nunca trocou tipo de molde: gira o prop e, com Shift, troca a face. A troca de molde ficou toda na roda radial.
- **O molde copiado na rua não é descartado** ao abrir a roda: vira um setor a mais.
- **O jogador continua andando com a roda aberta.** Só a câmera é travada, para o mouse escolher o setor.

## Armadilhas encontradas

- `String(valor)` recusa parte dos Variants que podem vir de um `ConfigFile` editado à mão ("Invalid call 'String' constructor"). Em código que sanitiza entrada de disco, usar `str()`.
- Sem o deslocamento vertical da roda (`LIFT`), o rótulo do setor de baixo caía em cima da barra de ações; com a legenda acima, ela batia no painel de status. A roda sobe 56 px e a legenda fica abaixo, na folga aberta.
- `routes_pause_integration` falha 2 verificações quando rodado com `--headless`: sem servidor de vídeo não existe `MOUSE_MODE_CAPTURED`. **Não é regressão** — rodar esse teste com janela.

## Evidência

Godot 4.7 no Windows, projeto reimportado sem erro de script.

| Verificação | Resultado |
|---|---|
| `mold_loadout_integration` (novo) | 111 verificações, 0 falhas |
| `city_regression` | 607.767, 0 falhas |
| `city_scale_integration` | 22.375, 0 falhas |
| `placement_integration` | 168, 0 falhas |
| `character_integration` | 203, 0 falhas |
| `wardrobe_integration` | 56, 0 falhas |
| `conversion_playable` | 13, 0 falhas |
| `recovery_check` | 6, 0 falhas |
| `cars_on_road` | 228 amostras, 0 falhas |
| `routes_pause_integration` (com janela) | 17, 0 falhas |
| `placement_coverage` | 540/540 amostras válidas |
| Partida headless | 1.200 quadros, sem erro |
| Smoke gráfico | 60,0 FPS médios, 64 civis |

Imagens: `mold-kit-preview.png` (tela de pré-partida) e `mold-wheel-preview.png` (roda em jogo).

### Matriz coberta pelo teste

Saneamento (válido, vazio, repetido, tipo inexistente, excesso, entrada que nem é lista), persistência de ida e volta, composição da roda (com e sem molde copiado), geometria de 2 a 7 setores incluindo as fronteiras, e em jogo: abre e troca, solta no centro sem trocar, Esc cancela, botão direito com isca na mão cancela a colocação em vez de abrir a roda, entrar em colocação fecha a roda, policial não tem roda.

## Pendências

- Playtest do autor. Sem commit.
