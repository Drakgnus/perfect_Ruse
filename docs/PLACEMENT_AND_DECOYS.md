> Historico do Bloco 2. As regras de rua, altura e espacamento abaixo foram substituidas pelo pedido posterior do autor. Regras e controles atuais: [Cidade e controles](CITY_AND_CONTROLS.md).

# Colocação e iscas — Bloco 2 (20/09/2026)

Continuação do Bloco 1 do Claude: preserva lojas volumétricas, cidade, carros e ajuste dos olhos. Implementação single-player; não porta regras para o POC multiplayer.

## Como usar

1. Copie um molde com C perto de um objeto.
2. Q prepara um esconderijo com todo o dinheiro carregado; T prepara uma isca vazia.
3. Mire um ponto livre na rua/calçada. Verde indica posição válida; vermelho indica bloqueio.
4. Clique esquerdo inicia 0,8 segundo de preparação. O anel nos pés indica progresso. Andar, Esc, botão direito, paralisação, conversão ou fim da partida cancelam.
5. O dinheiro só sai da mão ao concluir. O local é verificado novamente: carro ou objeto que entrou durante a preparação impede a colocação, sem consumir dinheiro.
6. Como policial, use E perto do objeto para inspecionar por 1,6 segundo. Esconderijo recupera dinheiro; isca é destruída, sem recompensa, liberando espaço e cota. Bots usam a mesma resolução. O texto da inspeção não revela antecipadamente o conteúdo.

## Implementação

- `main.gd` valida localização no commit, inclusive chamadas dos bots: limites, altura, quarteirões, espaçamento e colisão. Carros móveis bloqueiam; personagens e o fantasma de prévia não bloqueiam.
- `player.gd` mantém intenção de clique para a etapa de física, controla preparação e cancelamento. Não há novo clipe esquelético: o gesto é uma inclinação breve do modelo existente.
- `placement_feedback.gd` desenha o anel segmentado, poeira, fragmentos e assentamento visual de 0,22 segundo. A colisão já nasce no chão. Exceção específica autorizada no Bloco 2 à restrição antiga de animar props: somente transição de colocação; objetos permanecem imóveis depois.
- Usa sons já licenciados do jogo (`hide_money`, `frisk`), sem serviço externo ou geração paga.
- Restaurados grupo `robbable` e cooldown das seis lojas, perdidos na troca do painel pelo volume.
- Revelação de policiais usa Timer filho do marcador, reiniciado em revelações repetidas. Elimina callback que acessava objeto já liberado.

## Evidência

Executado em cópia atualizada do projeto, Godot 4.7 no Windows:

- Importação: concluída, sem erro de script.
- Personagens: 175 verificações; guarda-roupa: 56; colocação: 41. Zero falhas.
- Colocação inclui cancelamento, pedestre, carro entrando durante preparação, proteção do saldo, empilhamento, conversão, lojas, inspeção humana de 1,6 segundo, destruição e recuperação de dinheiro.
- Partida headless: 1.200 frames, sem erro do jogo.
- Auditoria de carros do Claude: 54 amostras, zero fora da pista.
- Smoke gráfico: 180 frames, média local 48,8 FPS, 40 civis. Medida pontual, não benchmark de desempenho.
- Captura real: `placement-progress.png`, durante metade da preparação.

Comando: `python tools/run_character_checks.py character-tests wardrobe-tests game-1200 visual-smoke placement-tests cars-on-road placement-capture`.

O runner reprova também `ERROR:` do motor, mesmo com exit code zero; ignora apenas a mensagem conhecida de leitura do certificado raiz do Windows nesta execução isolada. Logs em `docs/placement-validation/`. Playtest manual do autor ainda necessário para avaliar sensação dos controles.

## Tentativas e prevenção

- A suíte antiga aceitava erros comuns do motor porque buscava apenas `SCRIPT ERROR`. A inspeção dos logs encontrou captura de marcador já liberado. Corrigidos timer e filtro; sucesso exige também log sem erro do jogo.
- O primeiro teste acelerado encerrou enquanto OGG ainda tocava: 37 regras passavam, mas havia recurso de áudio em uso. Log verbose identificou `hide_money.ogg`; o teste agora aguarda término dos efeitos antes de destruir a cena. Não ocultar erros de recursos no runner.
- Uma edição auxiliar via Python inline falhou na análise de aspas do PowerShell, sem alteração de arquivo. Substituída por patch direto; preferir arquivos UTF-8/patches para código multilinha.

Não alterados: assets de personagens/Blender, direção de arte da cidade, população ou regras do POC de rede. Novos packs de ambiente pertencem ao Bloco 3.
