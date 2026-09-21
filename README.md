# Perfect Ruse

Protótipo em Godot de roubo, disfarce e perseguição policial em uma cidade. Base atual single-player com bots; experimento multiplayer isolado em `multiplayer_poc/`.

## Executar

Abra `project.godot` no Godot compatível com a versão usada pelo projeto (validação local: 4.7) e execute com F6 a cena desejada ou F5 para o menu. Aguarde a importação dos assets no primeiro uso. Não é necessário Blender para jogar; `source/citizen.blend` é a fonte editável do personagem.

## Documentação e próximos trabalhos

Comece por [docs/README.md](docs/README.md). A direção solicitada em 21/09/2026 está em [análise urbana e visual](docs/URBAN_GAMEPLAY_PLAN.md), com [critérios de assets](docs/ART_DIRECTION.md) e [backlog](docs/BACKLOG.md).

A correção de contato com o chão (#2) foi implementada; as demais propostas seguem planejadas. Consulte [o handoff para o Claude](docs/CLAUDE_HANDOFF.md) e [a avaliação de lançamento](docs/GAMEPLAY_RELEASE_REVIEW.md). O GitHub Issues passa a organizar a execução; `CODEX_QUEUE.md` e `CODEX_TASKS.md` preservam o histórico.

## Validar

No PowerShell, na raiz:

```powershell
$env:GODOT_BIN = 'D:\Programas\Godot\Godot_v4.7-stable_win64.exe'
python tools/run_character_checks.py game-1200 visual-smoke
```

O runner usa `runtime-profile/`, cria logs locais e precisa de janela/GPU para `visual-smoke`. Consulte [evidência desta publicação](docs/validation/2026-09-21/README.md). A suíte completa contém testes adicionais; os dois comandos acima não certificam todas as mecânicas.

## Assets e versionamento

Créditos conhecidos em [assets/CREDITS.md](assets/CREDITS.md); licenças dos packs em suas pastas. Não foi atribuída uma nova licença global ao código ou às fontes do autor. O repositório guarda projeto, modelos, fontes, testes e documentação; caches Godot, perfis locais, downloads temporários e backups automáticos ficam fora do Git.
