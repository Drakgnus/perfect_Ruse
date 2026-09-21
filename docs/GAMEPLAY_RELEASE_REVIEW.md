# Avaliação do jogo, balanceamento e lançamento

Data: 21/09/2026. Escopo: inspeção de regras, auditoria executável, avaliação técnica e plano de playtest. Não representa pesquisa de mercado nem partidas com pessoas. Não há evidência suficiente para afirmar que o jogo está equilibrado ou será comercialmente viável.

## Parecer

O conceito tem uma identidade compreensível: roubar, administrar risco, esconder dinheiro em objetos comuns, assumir a identidade de civis e despistar uma polícia que precisa observar. A conversão de preso em policial mantém o jogador participando. Recomendo desenvolver esse núcleo antes de ampliar catálogo e acabamento. O chibi atual combina com humor, acessórios reconhecíveis e leitura de disfarces; não vejo justificativa, nesta avaliação, para começar pela substituição completa do personagem.

Estado atual: protótipo jogável/pre-alpha. Preparar um teste fechado de mecânicas é o próximo marco recomendado. Não recomendo lançamento pago nem demo pública representativa antes dos bloqueadores abaixo. Sem público-alvo/plataforma definidos e dados de playtest, não há base para prometer uma data. A pergunta sobre modalidade de lançamento foi feita ao autor; enquanto não definida, as etapas abaixo distinguem teste fechado, demo e produto pago.

## O que funciona como proposta

- Roubo cria pressão; carregar dinheiro deveria expor o ladrão; esconder deveria reduzir o risco e oferecer trabalho dedutivo à polícia.
- Copiar a aparência e tirar a vítima da multidão evita duas identidades iguais e faz o disfarce ter consequência visual.
- Iscas e esconderijos saem da mesma fábrica de objetos, uma boa base para enganar pela observação.
- Conversão elimina espera de um jogador preso, mas muda o equilíbrio de forças durante a rodada.
- Cidade pequena, caminhos alternativos e becos com risco combinam melhor com esse ciclo do que longos deslocamentos sem decisões.

Esses pontos são avaliação de design, não prova de diversão. A implementação ainda permite estratégias que contornam parte do ciclo.

## Achados prioritários

| Prioridade | Evidência atual | Efeito provável / decisão necessária |
|---|---|---|
| P0 | `team_money` conta carregado + escondido; meta 1.500; sete ladrões com 250 = 1.750; nervosismo cresce apenas acima de 300 | Auditoria encerrou em `thieves_won` com zero escondido e zero nervosismo após 10 s. É possível vencer sem explorar a mecânica central; escolher o que constitui dinheiro pontuado/seguro. |
| P0 | `face_direction(..., true)` orienta a frente visual +Z; percepção de bot usa -Z | Auditoria mediu produtos escalares +1 visual / -1 percepção para o mesmo alvo. Unificar convenção por papel: jogador tem câmera/orientação próprias; não trocar sinal globalmente sem testes. |
| P0 | Polícia considera `carried_money > 0`, mesmo parado e sem tremor; após adquirir alvo acompanha sua posição diretamente, sem regra de perda de visão | IA sabe mais que o humano e disfarce/esquina não garantem despiste coerente. Definir pistas observáveis, última posição conhecida, busca e reaquisição. |
| P0 | `find_police_interactable` oferece inspeção somente a objetos registrados em `placed_objects`; objeto comum idêntico não oferece ação | O prompt revela que o objeto foi colocado. Auditoria: mesma caixa não é inspecionável como cenário e passa a ser quando registrada como isca. A aparência idêntica não basta para esconder essa informação. |
| P1 | `claim_suspect_stash` consulta diretamente registros recentes, inclusive sem teste de visão, e marca `claimed` | IA encontra candidatos por conhecimento interno; revisar pistas e liberação da reserva ao abandonar busca para não deixar objetos permanentemente ignorados. |
| P1 | Jogador corre a 6; bot policial aproxima a 4,8; ladrão bot foge a 4,6; policial humano usa a mesma velocidade 6 do jogador | Equilíbrio contra bots não representa PvP. Corrida livre favorece humano fugindo do bot, enquanto bot ladrão é mais lento que polícia. Não corrigir só aumentando velocidade: validar alcance, obstáculos, interceptação e duração. |
| P1 | Minimap desenha policiais sempre; Informante promete revelar por 6 s | Informação já disponível reduz valor da habilidade. Definir o que é público e o que exige pista/habilidade, por equipe. |
| P1 | Não há prazo de encerramento; polícia vence convertendo todos | Um ladrão sem dinheiro pode evitar condenação indefinidamente: revista limpa libera e marca por 20 s. Definir duração, desempate e obrigação de progresso antes de liberar partidas públicas. |
| P1 | Alerta global dura 8 s, redireciona todos; investigação a 4,2 m/s | Alcance teórico de resposta em uma janela é 33,6 m sem obstáculos, menor que o espaçamento de 64 m. Alertas sucessivos podem cancelar deslocamentos úteis; medir cobertura e separar patrulha/resposta. |
| P1 | Inspeção usa distância à origem do objeto; colocação alcança superfícies a 6 m, aceita paredes/tetos e sobreposição | Esconderijo pode ficar fora do alcance de inspeção ou dentro de outro volume. Preservar liberdade pedida pelo autor, mas garantir recuperabilidade e evitar esconderijo invulnerável. Reproduzir casos antes de impor restrições novas. |
| P1 | Multiplicador de roubo é compartilhado por tipo entre ladrões | Um colega reduz o rendimento de outro; comparar anti-camping por alvo, por jogador ou por equipe. Não presumir que o comportamento compartilhado é desejado. |
| P2 | Identificação por roupa funciona, mas F não possui custo/cooldown próprio no trecho inspecionado; alívio de 55 de nervosismo | Alternar roupas pode neutralizar pressão; avaliar por playtest, sem inventar cooldown antes de medir. |

P0 nesta tabela significa bloquear uma validação confiável do ciclo competitivo, não falha de execução ou segurança.

## Economia e pressão

Valores base: NPC 100 instantâneo; carro parado 180/3,5 s; carro de trânsito parado 200/3 s; ATM 250/4 s; loja 450/7 s. Esses valores brutos não incluem deslocamento, cooldown, linha de visão, risco ou rendimento decrescente. Comparar só dinheiro por segundo favoreceria conclusões erradas.

Repetir um tipo reduz multiplicador a 70% do anterior, piso 35%, recuperando 0,05 por segundo. O primeiro recuo de 1 para 0,7 se recupera em 6 s; deslocamento e canalização podem anular boa parte desse efeito. É hipótese a medir com telemetria de rota, não prova de que o sistema falha em todo cenário.

Acima de 300, nervosismo sobe a `2,2 × (1 + excesso/400)` por segundo; limiar visual 40. Com 450 carregados, são aproximadamente 13,2 s até esse limiar partindo de zero; com 250, não cresce. O Contrabandista multiplica a subida por 0,6. Esconder todo o dinheiro corta a pressão de carregamento, mas hoje esconder não é exigência de vitória.

Experimento recomendado: comparar regras candidatas de pontuação em um cenário pequeno, antes de decidir. Exemplos: dinheiro só pontua quando escondido e mantido por uma janela; ou existe entrega/extração exposta. Não implementar os dois sistemas ao mesmo tempo. Manter claro para a polícia como contestar a vitória e para o ladrão quando ganhou. Um cronômetro com regra explícita de encerramento deve evitar impasse.

## Conversão e papel policial

A conversão pode ser o diferencial social do jogo, porém cada captura simultaneamente reduz ladrões e aumenta policiais. Medir duração das rodadas após primeira captura, taxa de virada e experiência do último ladrão. Um jogador convertido também lembra esconderijos e planos do antigo time; isso é consequência de design, não informação que a interface consegue apagar.

O resultado mostrado usa o time atual do jogador. Avaliar se ser capturado voluntariamente para juntar-se ao lado vencedor cria incentivo ruim. Definir pontuação individual/participação e significado de vitória sem incentivar sabotagem do time inicial.

A revista limpa custa tempo e concede marca temporária, mas não há outra consequência evidente para abordar inocentes. Testar se revistar indiscriminadamente domina a observação. Qualquer custo adicional deve vir de teste: polícia precisa ter ações úteis e chance de entender por que perdeu um suspeito.

## Plano de validação

1. Corrigir percepção, vazamentos de informação e encerramento de rodada; isso vem antes de coletar taxa de vitória como evidência de equilíbrio.
2. Usar uma fatia pequena da cidade com os mesmos assets. Validar roubar → carregar risco → esconder → investigar → recuperar/converter → encerrar.
3. Rodar testes de tarefas com 5–8 pessoas novas, alternando papel: aprender roubo, disfarce, esconderijo, inspeção e objetivo sem explicação do desenvolvedor após o início.
4. Depois realizar ao menos 30 rodadas comparáveis por conjunto de regras, registrar papel/experiência/mapa/semente/composição. Separar partidas de bots e humanas; não agregar tudo como uma taxa única.
5. Medir: duração, tempo ocioso/deslocamento, origem e destino do dinheiro, uso e sucesso de disfarce/isca, motivo de detecção, buscas sem pista, recuperação, conversões, situação do último ladrão, erros e vontade de jogar novamente.
6. Como faixas de investigação, não lei: rodadas de 6–10 minutos e vitórias dos lados dentro de 40–60% com habilidades comparáveis. Amostras pequenas têm incerteza alta; não publicar promessa de equilíbrio baseada em 30 jogos. Priorizar partidas entendíveis e derrotas percebidas como justas.

A base principal atual não tem multiplayer completo. Os primeiros testes podem ser de tarefas single-player e polícia após conversão. Um teste humano dos dois times requer integrar rede ou criar uma ferramenta explícita de seleção de papel; não anunciar que o POC já permite a partida completa.

## Quando faz sentido lançar

| Marco | Critério de entrada recomendado | Situação atual |
|---|---|---|
| Teste fechado técnico | Build que abre fora do editor, instruções curtas, ciclo terminável, coleta de feedback; participantes informados das limitações | Próximo objetivo; exportação distribuível não foi validada nesta entrega |
| Teste fechado de gameplay | P0 corrigidos, partida com resultado e sem impasse, tarefas compreendidas, nenhuma estratégia óbvia invalida esconder/disfarçar | Ainda bloqueado pelas regras acima |
| Demo pública | Recorte representativo com tutorial, controles/opções, desempenho e estabilidade em máquinas-alvo, feedback dos dois papéis, loop que convida a repetir | Ainda não indicado |
| Lançamento pago | Qualidade da demo mais conteúdo/variedade suficientes, promessa de produto atendida, suporte e operação definidos; se vendido como multiplayer, rede completa e testada sob condições reais | Prematuro; não estimar data sem escopo/equipe/dados |

Rede, caso seja a promessa: servidor autoritativo para dinheiro, revista, colocação, cooldowns e vitória; testes com latência/perda, desconexão, reconexão/saída do host e privacidade por time. POC sincroniza movimentação de cápsulas e não entrega essas mecânicas. Escolher arquitetura operacional antes de anunciar capacidade de jogadores.

Build: validar instalação/execução em máquina limpa, presets de exportação, mapeamento de controles, volume/sensibilidade/resolução, legibilidade de UI, créditos e permissões dos assets. Não há `export_presets.cfg` no diretório inspecionado; isso não prova que nunca houve um build externo, apenas que não foi encontrado aqui.

A data deve surgir depois de duas rodadas de playtest sem mudanças estruturais do loop. Não esperar todos os assets finais para testar diversão; também não usar uma arte mais realista como substituto para validação da mecânica. O próximo investimento de maior valor é corrigir justiça/informação/objetivo e testar uma quadra, preservando a base visual chibi.

## Evidência e limites

Auditoria reproduzível: `tools/gameplay_audit.gd`; saída em [observations.json](validation/gameplay-audit/observations.json). Ela chama regras reais em estados controlados e confirma os exemplos indicados. Não mede taxa de vitória, retenção, diversão, mercado ou robustez de multiplayer.

Código-base auditado: `main.gd`, `police.gd`, `player.gd`, `thief_bot.gd`, `minimap.gd`, `abilities.gd`, `city_builder.gd`; escopo de rede conferido em `docs/MULTIPLAYER_POC.md`. Esses arquivos de regras não foram alterados pela avaliação. A correção de contato visual da issue #2 é entregue separadamente, com testes próprios.
