# Handoff para o Claude — 21/09/2026

## Onde continuar

Projeto correto: `D:/Jogos/MeuJogo/perfect-ruse` (Godot). Repositório: https://github.com/Drakgnus/perfect_Ruse, branch `main`. Não trabalhar no ZeonHub: ele era apenas o diretório inicial da sessão. Antes de editar, conferir `git status`, `git log -3 --oneline`, issue e dependências. Este handoff integra o commit de entrega; o hash exato está no histórico e nos comentários das issues #2 e #10.

Leia README, docs/README, este handoff, docs/BACKLOG e os documentos específicos. CODEX_QUEUE/CODEX_TASKS são históricos e contêm decisões antigas; não reiniciar por uma tarefa velha marcada pendente.

## Pedidos do autor

1. Analisar e planejar cidade compacta, quadras retangulares/variadas, fachadas encostadas, poucos becos sem saída e perseguição justa.
2. Corrigir personagens/carros flutuando; depois melhorar/variar objetos copiáveis e harmonizar prédios/carros.
3. Manter personagem chibi se fizer sentido; pode sugerir melhoria, sem presumir troca completa.
4. Publicar projeto, documentos e issues no GitHub. Isso foi feito.
5. Autor disse “ok comece”: foi iniciada e concluída a issue #2.
6. Durante a execução pediu avaliação de mecânicas, balanceamento e quando lançar. Avaliação concluída e registrada; mudanças nas regras ainda não implementadas.
7. Por último pediu este registro para o Claude continuar. Não há outra tarefa de código em andamento após a entrega.

Modalidade de lançamento (teste fechado/demo/pago) foi perguntada, mas não respondida até a preparação deste handoff. Não tratar a recomendação de teste fechado como decisão expressa do autor. Não foi definido prazo de lançamento.

## Entregue nesta etapa

**Issue #2 — contato com o chão:** carros móveis em Y=0,008 em vez de 0,15; estacionados na altura real do topo da vaga (0,1505). Personagens usam curvas de contato obtidas da malha animada para idle/walk/run, calçados/descalços, em vez do deslocamento fixo +0,038. Apoio corrigido nas transições e rampas; tremor horizontal preservado. GLB, rig, roupas e regras da partida não foram alterados.

Arquivos de implementação: scripts/city_builder.gd, traffic_car.gd, character_base.gd, modular_character.gd; novos scripts/character_contact.gd e ground_contact_profiles.gd. Gerador: tools/build_ground_profiles.gd; teste: tests/ground_contact_integration.gd; runner tem opção ground-contact.

**Avaliação:** docs/GAMEPLAY_RELEASE_REVIEW.md, com evidência reproduzível tools/gameplay_audit.gd e docs/validation/gameplay-audit/observations.json. Issues #10–#15 criadas; #5 recebeu as novas dependências. Auditoria registra problemas presentes, não testes de aceite para perpetuar essas regras.

## Evidência e limites

- Apoio: 516 verificações, zero falhas. Clipes planos: 1,1–3,2 mm; rampa testada: penetração residual máxima 12,8 mm, dentro do limite de 20 mm. Não é IK de pés para terreno arbitrário.
- Personagens: 203; guarda-roupa: 56; colocação: 168; carros: 228; cidade: 607.767 comparações/3 mundos; rotas e pausa: 17; conversão: aprovada.
- Partida: 1.200 frames sem erro; smoke: média local 60 FPS/180 frames/64 civis. Não é benchmark em hardware mínimo.
- Depois da correção final de rampas, repetidos apoio/personagens/guarda-roupa/partida/smoke/rotas. Logs e capturas em docs/validation/ground-contact; detalhes e tentativas em docs/GROUND_CONTACT.md.
- Nenhum playtest humano, rede completa, taxa de vitória ou build comercial foi validado. Não chamar o jogo de equilibrado ou pronto para venda.

## Próxima prioridade recomendada

Começar pela **#11: percepção policial**. Inspeção e objetivos (**#12/#13**) são pré-condições de medir equilíbrio. **#14** trata informação/habilidades; **#15** build/rede do teste; **#10** acompanha prontidão. Não implementar todas de uma vez sem preservar escopo e evidências por issue.

Achados confirmados:

- Sete ladrões carregando 250 cada vencem sem esconder nada; meta 1.500, total 1.750 e nervosismo zero nesse valor.
- Frente visual do bot orienta +Z, cone de visão usa -Z. Produto escalar auditado +1 versus -1. Jogador/câmera têm convenções próprias: corrigir por papel e testar, sem replace global cego.
- IA detecta dinheiro interno mesmo sem pista visual; acompanha posição do alvo após perder visão. Revisar memória de última posição vista/disfarce.
- Caixa comum não oferece inspeção; a mesma caixa registrada como isca oferece: UI revela objeto colocado. Bot também consulta registro interno.
- Minimap revela polícia continuamente, enfraquecendo Informante.
- Sem limite de rodada; jogador sem dinheiro pode evitar conversão. Conversão muda 7×3 progressivamente e pode incentivar trocar de time para vencer.

A análise separa esses achados das hipóteses a medir. **Não foram corrigidos nesta entrega**: o usuário pediu avaliação e continuidade pelo Claude, não uma mudança silenciosa de todas as regras.

Depois dos bloqueadores do ciclo, retomar #3/#4 (mapa e navegação) e #5 (playtest), com proposta inicial de 224×160 apenas como hipótese. Mapa atual continua 256×256, ROAD_SPACING 64, sem alteração de layout nesta etapa. #6/#9 amostra de arte/personagem; #7/#8 catálogo e ambiente continuam pendentes. Nenhum asset novo foi baixado/comprado.

## Armadilhas e manutenção

- Perfis têm hash do citizen.glb; se trocar asset, regenerar com renderização real e executar ground-contact. Não editar milhares de amostras à mão.
- Hulls assumem pés rigidamente ligados a um osso, como o gerador do personagem atual. Alterar skin/rig exige revisar essa hipótese.
- GPU bake serve para gerar/validar; não introduzir readback por frame em todos os NPCs.
- Transições de clipes podem flutuar mesmo quando cada clipe isolado está correto; teste cobre isso.
- Skeleton pode emitir callback durante remoção da prévia; manter guards de árvore/instância.
- `is_on_floor` não prova apoio visual: teste independente mede malha e superfície da rampa.
- Testes rotas/pausa e apoio precisam de renderização/janela; não rodar como headless e suprimir falhas.
- Regras continuam em main.gd; não mexer no POC multiplayer incidentalmente. Preservar colocação livre/sobreposição pedidas pelo autor enquanto se desenha recuperabilidade.
- Não misturar resultados atuais com números históricos de docs anteriores.

## Reproduzir

```powershell
Set-Location D:/Jogos/MeuJogo/perfect-ruse
python tools/run_character_checks.py character-tests wardrobe-tests conversion-playable cars-on-road routes-pause placement-tests city-tests game-1200 visual-smoke ground-contact
$env:APPDATA = "$PWD/runtime-profile"
& 'D:/Programas/Godot/Godot_v4.7-stable_win64.exe' --headless --path . --log-file gameplay-audit.log --script res://tools/gameplay_audit.gd
```

Ao encerrar próxima issue: atualizar docs/issue, guardar evidências, distinguir testes automatizados de playtest, commitar e publicar no repositório autorizado.
