# Apoio de personagens e veículos — issue #2

Entrega: 21/09/2026. Corrigido e validado localmente; base chibi e GLB original preservados.

## Diagnóstico e solução

- Trânsito tinha origem Y=0,15 e rodas em Y local zero: cerca de 14 cm acima da rua. Agora usa ROAD_SURFACE_Y=0,008; pavimento visual existente tem topo 0,007–0,008. Movimento, freio e regras de roubo permanecem iguais.
- Estacionados tinham origem Y=0,12, mas o topo visual da vaga é 0,1505: rodas penetravam aproximadamente 3 cm. Agora usam PARKING_SURFACE_Y, derivado da geometria da vaga. Fallback de caixa também passa a ter base zero.
- Personagem com antigo deslocamento fixo +0,038 tinha solas aproximadamente 5,7 cm acima da origem no idle. Walk/run variavam ao longo do clipe. O GLB não foi reexportado nem deformado: curvas de posição vertical são adicionadas às cópias compartilhadas dos clipes, separadas para sapatos/pés descalços.
- `ground_contact_profiles.gd` é gerado a 120 Hz a partir da malha animada real, com hash do GLB. `character_contact.gd` corrige a pose misturada durante transições e o contato no plano físico de rampas; usa hulls dos pés em CPU, sem bake/readback gráfico por personagem durante o jogo.
- O tremor continua horizontal e com olhar lateral/suor, sem deslocamento vertical e rotação lateral que levantavam as solas. Limiares e regras de suspeita permanecem iguais.

## Arquivos

`city_builder.gd`, `traffic_car.gd`, `character_base.gd`, `modular_character.gd`; novos `character_contact.gd` e `ground_contact_profiles.gd`; gerador `tools/build_ground_profiles.gd`; teste `tests/ground_contact_integration.gd`, integrado ao runner como `ground-contact`.

## Evidência

[Capturas, medições e logs](validation/ground-contact/): 516 verificações, zero falhas. Inclui clipes idle/walk/run calçado e descalço, tempos entre as chaves geradas, transições, geometria das quatro rodas dos seis modelos, carros nascidos pelas funções reais, movimento nos dois eixos, subida e parada na calçada.

Clipes sobre piso plano: apoio entre 1,1 e 3,2 mm nas amostras. Na rampa testada: penetração residual de até 12,8 mm, dentro da tolerância de 20 mm definida para esta etapa. Não é IK independente de cada pé, nem alinhamento perfeito a qualquer terreno; o pé em balanço não é forçado ao chão. Veículos continuam em vias planas, sem nova suspensão.

Regressões executadas: personagens 203; guarda-roupa 56; colocação 168; carros 228; cidade 607.767 comparações em três mundos; rotas/pausa 17; conversão aprovada; partida de 1.200 frames aprovada. Smoke gráfico: 180 frames, média 60,0 FPS e 64 civis na máquina local, sem extrapolação para outros hardwares. Capturas focais de personagem e carro foram inspecionadas.

Comando da bateria relevante:

```powershell
python tools/run_character_checks.py character-tests wardrobe-tests conversion-playable cars-on-road routes-pause placement-tests city-tests game-1200 visual-smoke ground-contact
```

Depois da última adaptação às rampas foram repetidos apoio, personagens, guarda-roupa, partida, smoke e rotas/pausa. Testes de cidade/colocação/carros passaram na mesma entrega antes desse ajuste visual; não foram repetidos sem necessidade.

Para regenerar após mudar o GLB, usar renderização real (não headless):

```powershell
$env:APPDATA = "$PWD/runtime-profile"
& 'D:/Programas/Godot/Godot_v4.7-stable_win64.exe' --path . --script res://tools/build_ground_profiles.gd
python tools/run_character_checks.py ground-contact
```

Gerador e teste usam [bake_mesh_from_current_skeleton_pose do Godot](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html#class-meshinstance3d-method-bake-mesh-from-current-skeleton-pose) para observar a pose renderizada. Não usar esse bake por frame na população do jogo.

## Tentativas que falharam e prevenção

1. Probe inicial consultou `get_path` antes de entrar na árvore e gerou erro de diagnóstico; o caminho raiz foi confirmado posteriormente. Não consultar transformações globais antes de a cena estar pronta.
2. Primeira versão do gerador tinha indentação inválida dentro do loop de vértices. Corrigida e executada novamente; nenhum GLB foi alterado.
3. Só corrigir curvas individuais deixou dez amostras de transição fora da tolerância. Misturar dois clipes apoiados não garante apoio da pose interpolada. Adicionado ajuste da pose misturada com hulls dos pés; manter teste de transição.
4. Callback de skeleton durante troca/remoção da prévia gerou erros no guarda-roupa, embora suas 56 asserções passassem. Adicionada proteção de ciclo de vida; runner corretamente reprovou logs com ERROR e a execução seguinte passou.
5. Medir apenas `is_on_floor` aprovava a rampa, mas a geometria revelava penetração de até 23 mm. Adicionado plano físico da rampa e asserção de folga da malha: máximo residual 12,8 mm no trajeto testado.

Anti-padrão: aceitar cápsula apoiada/AABB de repouso ou clipes isolados como prova de contato visual. Prevenção: medir malha animada, transições, superfície e troca de cena, além de inspecionar close-ups. Ao trocar sapatos/rig, regenerar perfis e revalidar a hipótese de cada pé ser rigidamente associado a um osso; o hull atual depende dessa construção do asset.
