# Bairro compacto, perseguição e evolução visual

Data: 21/09/2026. Estado: análise e planejamento; nenhuma mudança de gameplay aplicada nesta entrega.

## Pedido do autor

A cidade deve parecer construída e ter tamanho administrável. Ruas principais podem ser longas, mas ligações transversais devem permitir mudar de quadra sem contornar enormes quadrados vazios. Prédios encostados, com alguns becos de serviço sem saída para os fundos, substituem os vãos regulares. Preservar espaço para policiais perseguirem e para o ladrão usar disfarce e camuflagem. Corrigir personagens e carros aparentemente suspensos. Depois, ampliar e melhorar os objetos copiáveis e harmonizar prédios/carros com o personagem atual. Registrar agora para implementar quando solicitado.

## Evidências e diagnóstico

Leituras: CODEX_TASKS, CODEX_QUEUE, CITY_SCALE, CITY_AND_CONTROLS, CHARACTERS_MODULAR, MOLD_LOADOUT, PLACEMENT_AND_DECOYS, MULTIPLAYER_POC e créditos. Código inspecionado: city_builder, city_routes, character_base, modular_character, model_library, player, police, traffic_car e runner. Captura atual e smoke em `validation/2026-09-21/`.

| Item | Estado observado no código | Consequência |
|---|---|---|
| Mapa | ROAD_SPACING=64; MAP_HALF=128 | 256 × 256 m, 65.536 m²; eixos acoplados à mesma constante |
| Quadra construída | BLOCK_HALF=23,5 | 47 × 47 m dentro das calçadas |
| Fachada e passo | largura 8,4 m; RING_STEP=9,4 m | aproximadamente 1 m entre fachadas alinhadas; vãos não são becos deliberados |
| Miolo asfaltado | COURTYARD_HALF=14,1 | superfície de 28,2 × 28,2 m, cerca de 795 m², com apenas quatro props por pátio |
| Acesso ao pátio | vão removido do anel; piso de beco com 8,4 m de largura | escala próxima de rua, repetida em cada quadra construída |
| População | 64 civis | densidade aparente cai conforme área e espaços vazios crescem |
| Corrida | jogador 6 m/s; aproximação policial 4,8 m/s | numa reta livre o jogador abre 1,2 m por segundo, antes de habilidades/obstáculos |

A captura também mostra uma praça muito ampla. Praça/parque são espaços intencionais, distintos dos pátios internos: precisam ter proporção, cobertura e função próprias, não ser preenchidos indiscriminadamente.

Conclusão: o problema principal é a proporção entre ruas, profundidade dos lotes e espaço acessível. Aumentar o número de objetos ou diminuir tudo uniformemente não resolve. Portas, carros e personagens precisam conservar escala coerente.

## Proposta de primeiro protótipo

Trabalhar um bairro de poucos quarteirões, com prédios de fundo sugerindo continuação da cidade. Não simular uma cidade inteira. Começar com grade retangular legível; recortes em L, ruas em T e variação de quadras só depois de validar rotas. Retângulo é ponto de partida para evitar o quadrado repetido, não obrigação para todo lote.

Medidas abaixo são hipóteses de design para comparação, não especificação final aprovada:

| Parâmetro | Protótipo inicial | Motivo |
|---|---|---|
| Espaçamento entre eixos de ruas | 56–64 m no eixo longo; 36–44 m no curto | conservar uma rua extensa com mudança de quadra mais rápida |
| Exemplo de domínio | 224 × 160 m, mantendo quatro intervalos por eixo (56/40) | cerca de 45% menos área que 256²; ainda exige medir trajetos reais |
| Quadra no exemplo, com perfil viário atual de 17 m | 39 × 23 m | dois alinhamentos de edifícios de 8–10 m deixam pouco miolo residual |
| Via principal | começar preservando asfalto de 8 m | já comporta trânsito; não estreitar antes de verificar carros |
| Calçada | preservar inicialmente 4,5 m; garantir faixa útil contínua de pelo menos 2 m | estacionamento, postes e props não podem ocupar a faixa de circulação |
| Beco de serviço | 2,5–3,5 m de largura útil; 8–14 m de profundidade | acesso legível aos fundos, sem virar segunda avenida |
| Pátio acessível | seletivo, aproximadamente 6–10 × 8–12 m | espaço de serviço com função, em vez de grande vazio em todas as quadras |
| Fachadas | continuidade, sem passagem entre edifícios contíguos | diversidade por altura, cor e uso, não por isolamento de cada prédio |

Não basta mudar ROAD_SPACING: separar dimensões X/Z, limites, centros de lote e rede de ruas; revisar minimapa, spawns, estacionamento, semáforos, rotas e testes. Validar primeiro uma quadra e uma perseguição, depois expandir.

Paredes compartilhadas podem encostar sem interpenetrar; resolver telhados, cornijas e detalhes de esquina. Remover vãos caminháveis acidentais. Preencher fundos com anexos, volumes ou pátios fechados visualmente plausíveis. Espaço não jogável deve ser inequívoco e ter colisão coerente.

Distribuição inicial: alguns becos sem saída, não um em toda quadra; uma praça menor como referência; parque proporcional. Um eventual atalho atravessável é categoria separada, deliberada e sinalizada. Não transformar todos os becos em rotas de fuga garantidas.

## Perseguição e justiça

A 6 m/s, percorrer 64 m leva 10,7 s; 40 m leva 6,7 s; 56 m leva 9,3 s. A 4,8 m/s, o policial percorre essas mesmas distâncias em 13,3 / 8,3 / 11,7 s. São distâncias retas entre eixos, sem curva, tráfego ou colisão. Cruzar 256 m em linha reta leva 42,7 s ao jogador; um caminho urbano real será maior.

A polícia atual move diretamente na direção do alvo em `_move_towards`; fechar fachadas sem navegação compatível pode piorar seu comportamento e prendê-la nos edifícios. A rede de destinos dos civis não comprova que uma perseguição contorna paredes ou entra/sai de becos.

Antes de mudar velocidades, testar rotas de interceptação, perda e retomada de visão, busca da última posição observada e acesso aos becos. Atalhos não devem exigir atravessar paredes nem dar conhecimento oculto do ladrão. Guardar eventual revisão de velocidade/habilidade como decisão de balanceamento explícita.

- Retas permitem leitura e aproximação; esquinas permitem romper visão; ruas transversais dão opções de interceptar.
- Beco sem saída oferece cobertura e local para camuflar, mas cria risco de encurralamento. Fundo e entrada precisam ser legíveis; deixar espaço para giro/câmera e inspeção.
- Não espalhar lojas e ATMs tão longe que a polícia passe a partida em deslocamento. Também não concentrar todos em um ponto de camping.
- Manter objetos comuns suficientes perto das oportunidades de esconder dinheiro; não encher o cenário de ruído visual que torne revista inviável.
- Avaliar bots e jogadores humanos separadamente. A base atual (7 ladrões incluindo jogador, 3 policiais) não valida automaticamente o objetivo histórico multiplayer 16 × 4.

Playtest comparativo: mesma população, regras e conjunto de seeds no mapa atual e em duas variantes compactas; ao menos dez perseguições por variante, incluindo reta, esquina, praça, beco e trânsito. Registrar distância real, tempo até primeiro contato, duração de perseguição, perda/retomada de visão, captura/escape, distância percorrida pelo policial, travamentos, densidade de civis e tempo de busca em pátios. Relatar mediana e extremos; esse tamanho de amostra orienta iteração, não prova equilíbrio estatístico. Não definir taxa ideal de captura sem testar os dois papéis.

## Contato com o chão — prioridade inicial

Carros móveis: `traffic_car._ready` fixa Y=0,15, enquanto o topo visual do asfalto está aproximadamente em 0,007–0,008. `instance_fitted` alinha a base da malha à origem. Há portanto indício forte de folga visual de aproximadamente 14 cm, dependente do modelo. O movimento atual é horizontal, sem ajuste vertical ao piso. Validar pelas rodas reais, não somente AABB.

Carros estacionados: origem Y=0,12; topo visual da vaga aproximadamente 0,1505. Aqui o indício é de penetração de cerca de 3 cm, não a mesma flutuação dos móveis. Verificar por modelo e superfície; não aplicar um único deslocamento global a todos os carros.

Personagens: cápsula começa na origem; `modular_character` aplica +0,038 m por correção documentada dos pés nativos. Não remover esse valor sem medir. Poses idle/walk/run, sapatos versus pés descalços, tremor vertical em character_base, rampas, física e sombras podem contribuir. A captura geral não estabelece a causa nem certifica todos os estados.

Aceite futuro: medir distância roda/pé de apoio até a superfície real, com tolerância inicial de 1–2 cm a calibrar para escala e motor; não exigir que o pé em balanço toque o chão. Capturar vistas laterais próximas de cada modelo/estado; testar parada, movimento, rampas e troca de roupa. Sombras de contato complementam, mas não substituem correção geométrica. Não introduzir suspensão complexa antes de corrigir referência de apoio.

## Ordem de execução

1. Corrigir contato com o chão e criar evidência focal.
2. Prototipar quadra retangular, fachadas contínuas e becos.
3. Adaptar rotas, polícia, trânsito, limites, minimapa e spawns antes de integrar o mapa.
4. Comparar perseguições e ajustar dimensões/densidade.
5. Validar uma amostra visual com o personagem atual.
6. Melhorar e ampliar moldes copiáveis.
7. Harmonizar prédios e veículos depois de aprovar a amostra e o layout.

## Aprendizado e prevenção

A ampliação anterior de 36 para 64 m resolveu quantidade de prédios, mas não garantiu densidade nem boa perseguição; o autor ainda relata vazio. Anti-padrão: usar dimensão global para corrigir ocupação local. Prevenção: medir frente construída, miolo acessível, tempo entre esquinas e perseguição antes de escalar o mapa.

Os testes históricos de volumes e rotas aprovados não verificam automaticamente rodas/pés apoiados nem diversão. Acrescentar verificações específicas e playtest nas issues correspondentes. Não registrar estas pendências como corrigidas.

## Complemento do autor sobre personagens

É permitido sugerir melhorias no personagem se fizerem sentido para o tema. A recomendação inicial é manter a base chibi e avaliar ajustes na amostra de direção visual; a decisão pode ser não mudar. Ver ART_DIRECTION.md e a issue específica de avaliação.
