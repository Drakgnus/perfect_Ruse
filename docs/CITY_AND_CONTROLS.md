> Próxima evolução planejada em 21/09/2026: [bairro, perseguição e visual](URBAN_GAMEPLAY_PLAN.md). O texto abaixo documenta entregas anteriores; a proposta nova ainda não está implementada.

# Cidade, rotas, pausa e colocação livre — 20/09/2026

## Estado integrado

Continuação sobre a cidade mais recente do Claude, não sobre a versão antiga: mapa 144 × 144, ruas de 8 m, calçadas de 4,5 m, quarteirões de meia-largura 9,5 m, modelos Kenney novos, praça, bosque, 64 civis e 14 carros em movimento. Preservados os assets e a correção do teste de áudio do Claude. O deslocamento sem destino dos NPCs foi substituído pelo percurso entre destinos.

## Controles

| Ação | Controle |
|---|---|
| Pausar / continuar | Esc; se houver colocação ou mapa aberto, o primeiro Esc cancela esse modo |
| Sair da partida | Esc → Voltar ao menu |
| Fechar o jogo | Esc → Sair do jogo |
| Caminhar automaticamente | R → clique no mapa; o destino é ajustado à calçada acessível mais próxima |
| Olhar durante a caminhada | Mouse gira a câmera sem mudar o caminho |
| Interromper a caminhada | WASD ou R |
| Preparar esconderijo / isca | C copia molde; Q esconde dinheiro; T prepara isca |
| Girar objeto | Roda do mouse, em passos de 15° |
| Trocar a face de apoio | Shift + roda, em passos de 90° |
| Colocar | Mire chão, parede, teto ou outra superfície sólida a até 6 m e clique; preparação de 0,8 s |
| Mover uma isca já colocada | Mire uma isca sua e aperte V; ajuste a prévia e confirme com clique |
| Cancelar colocação / edição | Botão direito, Esc ou andar durante a preparação |

Iscas podem se sobrepor por pedido explícito do autor. Não há mais bloqueio por quarteirão, altura de chão ou espaçamento entre objetos. O objeto mantém a rotação e a altura da prévia; uma face encosta no plano atingido pela mira. Cancelar a edição mantém a isca original no lugar, sem consumir a cota. A polícia continua destruindo iscas ao concluir a inspeção de 1,6 s.

## Cidade e movimento

- Mantidos os novos prédios e seu limite de tamanho proporcional. Corrigido também o limiar de seleção do centro para usar o novo espaçamento de ruas.
- Calçadas elevadas foram divididas nos cruzamentos, com rampas e faixas correspondentes à rede de pedestres; não há uma chapa de calçada atravessando toda a avenida.
- Vagas de estacionamento ficam fora das faixas em movimento. A largura real dos modelos é limitada à largura reservada, preservando proporções. Caixas de colisão acompanham os modelos.
- Carros avançam por movimento físico, mantêm folga dos outros veículos e conferem espaço ao reaparecer na borda. Não atravessam obstáculos por atribuição direta da posição.
- A rede de calçadas conecta 12 destinos de lojas e ATMs. Civis partem de posições distintas, caminham, aguardam brevemente na chegada e escolhem outro destino. Atravessam pelas conexões sinalizadas e aguardam carros em movimento próximos.
- O percurso escolhido com R aparece no mapa. A orientação da câmera fica separada da direção de caminhada.
- A pausa interrompe a árvore do jogo, inclusive animações e trânsito. Ao continuar, os prazos baseados em relógio (alerta, revista, cooldown de roubo e tempo da partida) são compensados. Os timers de NPC respeitam a pausa.

As lojas continuam sem interiores jogáveis: a visita do civil termina na calçada próxima da entrada. Não foi implementada transformação do próprio jogador em objeto; o pedido desta etapa manipula iscas/esconderijos. A rede atual é uma malha de caminhos definida para esta cidade, sem navegação dinâmica completa para contornar qualquer bloqueio criado pelo jogador. Colocação em veículo móvel grava uma posição no mundo; não transforma o objeto em passageiro do carro.

## Validação

Godot 4.7, cópia atualizada e integrada com os arquivos do Claude:

- Personagens: 199 verificações, zero falhas; guarda-roupa: 56.
- Colocação: 168 verificações, incluindo seis normais de superfície, quatro faces, rotação, câmera real, sobreposição, edição com dono, cancelamento e dinheiro.
- Cidade: 353.895 comparações em três gerações, zero falhas. Verificados prédios fora das ruas, todas as 38 viaturas/carros (24 estacionados + 14 móveis), ausência de sobreposição entre veículos/construções, caminhos com espaço para a cápsula do pedestre e trânsito que efetivamente avança. 660 frames físicos por geração.
- Auditoria de vias/vagas: 228 amostras, zero falhas. Usa grupos, não nomes de nós que o Godot renomeia automaticamente.
- Rotas/pausa com renderização real: 17 verificações, incluindo clique no mapa, câmera independente, compensação de relógios, chegada de NPC, travessia com subida de rampa e retorno ao menu. O botão Sair foi acionado em processo separado e encerrou o jogo.
- Partida: 1.200 frames sem erro do jogo. Smoke gráfico: 180 frames, média local de 91,4 FPS com 64 civis (medição pontual, não benchmark).
- Capturas reais em `urban-city.png`, `urban-wall-preview.png`, `urban-wall-placed.png`, `urban-route-map.png`, `urban-pause.png`.

Reprodução: `python tools/run_character_checks.py character-tests wardrobe-tests placement-tests city-tests cars-on-road routes-pause pause-exit game-1200 visual-smoke placement-capture`.

`routes-pause` requer janela/renderização real: o backend headless não captura o cursor, portanto não testa corretamente a rotação com mouse capturado. O runner reprova erros do motor mesmo com exit code zero; a única exceção é a mensagem de certificado raiz do Windows nesta execução isolada. Logs entregues em `docs/urban-validation/`.

## Tentativas, correções e prevenção

1. A auditoria antiga de carros via nomes amostrava apenas parte dos estacionados e verificava centros/largura nominal. Agora usa grupos, tamanhos reais e pares de volumes. Regra: posição do centro na pista não comprova ausência de colisões.
2. A primeira integração preservava vitrines e modelos de carro mais largos que a reserva; o teste de cápsula encontrou caminhos bloqueados. Foram ajustadas a faixa de estacionamento, a largura proporcional dos veículos e as posições dos ATMs. Não liberar caminhos somente por inspeção de imagem.
3. A caixa única de uma loja inclui ar entre fachada, toldo e balcão; usá-la como colisão produziu falsos positivos. Comparar as caixas físicas de cada componente, preservando o teste do volume visual contra as ruas.
4. Personagens reposicionados no mesmo frame ainda apareciam no estado físico anterior durante a auditoria de geometria. O teste passou a excluir seus RIDs explicitamente; pedestres não são construções fixas.
5. O teste de edição mirava o ponto de contato original da parede, que pode ficar acima da face visível após girar a caixa. Agora mira o corpo da isca, como o comando V exige.
6. O teste headless da câmera falhou porque não havia captura real de mouse. A mesma sequência passou com renderização; o teste permanece gráfico, sem mascarar a asserção.
7. Durante o trabalho, Claude ampliou a cidade e adicionou assets. A cópia foi atualizada e as alterações integradas antes da validação final. A instalação compara hashes e aborta se algum original tiver mudado depois da revisão; mantém backup dos arquivos substituídos. Nunca reinstalar uma cópia antiga inteira sobre o trabalho paralelo.

Sem commit. Playtest do autor continua sendo a avaliação da sensação de câmera, densidade e circulação; os testes acima cobrem os comportamentos descritos, não todos os arranjos possíveis de objetos criados em partida.


### Revisão de escala e comércio
O arranjo antigo de miniaturas foi substituído por quatro parcelas maiores por quadra construída. Portas de 2,5 m e andares de 3,2 m; lojas integradas aos térreos, com vitrines e toldos. Ver `CITY_SCALE.md` para medidas, capturas, validações e limitações.
