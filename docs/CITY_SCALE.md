> Próxima evolução planejada em 21/09/2026: [bairro, perseguição e visual](URBAN_GAMEPLAY_PLAN.md). O texto abaixo documenta entregas anteriores; a proposta nova ainda não está implementada.

# Escala e fachadas — 20/09/2026

A cidade usa metros de gameplay: portas de 1,5 × 2,5 m, andares de 3,2 m e edifícios de 8,4 × 8 m. Os 14 quarteirões construídos possuem quatro parcelas cada, com 56 edifícios de dois a seis andares. Praça e parque permanecem abertos. A frente e o fundo de cada quadra se orientam para as ruas.

As seis lojas agora ocupam o térreo dos edifícios: padaria, mercado, café, farmácia, livraria e boutique. Possuem vitrines, exposição de produtos, toldos listrados e identificação. Mantêm os valores, duração e cooldown do roubo. Seus destinos estão no nível do passeio, fora das paredes. As entradas são fachadas: esta entrega não implementa interiores acessíveis.

Residências possuem molduras, peitoris, varandas em parte das fachadas, jardineiras, cornijas e telhados em parte das casas de dois andares. Detalhes estáticos são agrupados em uma malha por cor por edifício. Colisões continuam nos volumes dos edifícios; elementos pequenos de decoração não bloqueiam pedestres. As ruas, calçadas com rampas, estacionamento e regras de trânsito existentes foram preservados.

## Validação

- `tests/city_scale_integration.gd`: 1.661 verificações, nenhuma falha. Portas reais, escala, volumes visuais sem sobreposição entre prédios, seis lojas distintas e seis ATMs.
- `tests/city_regression.gd`: 201.207 verificações em três mundos, nenhuma falha. Vias, trânsito em movimento e todos os segmentos de percurso de NPCs livres.
- Iscas: 168 verificações; rotas e pausa: 17, sem falhas.
- Smoke visual com 64 civis: média de 60 FPS nesta máquina após agrupamento das malhas. Não é garantia em outros computadores.
- Capturas reais: `city-scale-street.png` e `city-scale-shop.png`.

## Tentativas e prevenção

- A solução anterior limitava todos os modelos a 5,6 m e encolhia portas junto com as fachadas. Substituída por parcelas maiores e dimensões arquitetônicas fixas. Não voltar a ajustar escala pelo tamanho total do modelo sem conferir portas ao lado de um personagem.
- A primeira escrita intermediária misturou CRLF e LF; o parser rejeitou o arquivo. Normalizado antes da validação. Uma inferência de tipo em deslocamentos de parcelas também foi corrigida com Vector3 explícito.
- Fachadas com peças separadas obtiveram aproximadamente 47 FPS no smoke. Agrupar malhas por cor elevou o resultado para 60 FPS. Verificar desempenho junto da aparência antes de aumentar decoração.
- Execução direta inicial falhou ao abrir o log padrão do Godot. Validações subsequentes usaram perfil e log isolados na pasta temporária.

O código novo usa a Palette existente. Os assets importados anteriores continuam disponíveis e não foram removidos.


# Quadra em anel, beco e limite da cidade — 20/09/2026 (Claude)

Pedido do autor: "as quadras estao pequenas, parece vazia porque tem muitas ruas; apenas 2 predios concluiu a quadra". Era literal: com `ROAD_SPACING` de 36 m a quadra tinha 19 x 19 m e exatamente quatro predios, entao havia mais asfalto do que cidade.

`ROAD_SPACING` passou para 64 m. Como toda a escala deriva dessa constante, a quadra foi para 47 x 47 m e o mapa para 256 x 256 m. Cada quarteirao virou um ANEL de predios de frente para a rua: cinco fachadas nos lados ao longo de Z e tres nos perpendiculares, com as pontas removidas para os predios de esquina nao se atravessarem. Sao 15 predios por quarteirao e 210 no total, contra 56 antes. O miolo virou patio de asfalto acessivel por um unico BECO SEM SAIDA, que ocupa o vao de um predio e muda de lado a cada quarteirao, nunca na face principal, que e onde ficam loja e caixa eletronico. O patio recebe quatro props da mesma fabrica do cenario, entao serve de esconderijo real.

A cidade tambem foi fechada. Em volta do mapa corre uma fileira de predios de fundo (volume, cornija e faixas de janela agrupados em uma malha por cor, sem porta nem detalhe de fachada, porque sao noventa e poucos e ninguem chega perto) e, onde a rua encostaria na borda, entra barricada de concreto com faixas e pedras. Atras de tudo ha uma parede invisivel de 6 m. A partida acontece so dentro do dominio.

## Validacao

- `city_regression`: 797.847 verificacoes em tres mundos, nenhuma falha.
- `city_scale_integration`: 22.375 verificacoes, nenhuma falha, incluindo a de que duas fachadas nao podem se sobrepor.
- `placement`, `cars-on-road`, `character`, `wardrobe`, `conversion`, `routes-pause`, `pause-exit` e 1.200 frames: sem falha.
- Smoke visual com 64 civis: 56,5 FPS numa execucao isolada e 43,4 na bateria completa, contra 60 antes. Medicao pontual desta maquina, nao benchmark. Se cair mais, o primeiro corte e o detalhe de fachada dos predios do anel virados para o patio.

## Tentativas e prevencao

- Predio de fundo alinhado com uma rua reprovava `city_regression`: o teste compara coordenadas de rua em todo o mapa, mesmo fora do asfalto. A folga da borda passou a ser `ROAD_HALF + 6,0`, que cobre a meia-largura do volume.
- A barricada nasceu em cima da calcada do perimetro (`MAP_HALF - 2,5`) e travava a rota dos pedestres. Foi para `MAP_HALF - 0,5`, e as pedras ficaram do lado de fora.
- Predios de fundo nao entram no grupo `city_buildings`: esse grupo significa predio jogavel, e os testes cobram porta de 2,4 m de cada membro. Foi criado `backdrop_buildings`.
- Loja e caixa eletronico caiam no mesmo ponto da calcada, e como os dois viram destino de rota, dois civis nasciam exatamente no mesmo lugar. O caixa foi deslocado um predio para o lado.
- Ha 64 civis para 60 pontos da malha de calcada. Quem "da a volta" no indice agora ganha deslocamento lateral, senao nasce em cima de outro.
- `_create_prop_from_model` abandonava o corpo ja criado quando o modelo nao carregava, sem `free()`. Bug antigo, virava "ObjectDB instances were leaked" no runner. Corrigido.
- Testes com escala embutida foram parametrizados: `placement_integration` usava o literal 90 como "fora do mundo" e `city_scale_integration` esperava 56 predios. Nao voltar a escrever numero fixo de mapa em teste.
- `urban_visual_smoke` assumia que a face -Z do predio mais proximo do centro daria para a rua. Com o anel ela pode dar para o patio; agora o teste procura a primeira fachada que aceita a isca.
- O aviso de vazamento no `recovery` e intermitente (uma falha em tres execucoes, sempre com as 6 verificacoes corretas) e some com `--verbose`. Parece corrida de carregamento de modelo no encerramento, nao regressao de regra.
