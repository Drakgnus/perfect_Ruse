# Índice do projeto

## Leitura antes de implementar

0. [Handoff atual para o Claude](CLAUDE_HANDOFF.md).
1. [README do projeto](../README.md).
2. [Plano urbano e de gameplay](URBAN_GAMEPLAY_PLAN.md): pedido atual, diagnóstico, sequência e critérios.
3. [Backlog oficial](BACKLOG.md): issues, dependências e estado.
4. [Direção visual](ART_DIRECTION.md) para modelos, materiais e moldes.
5. Documentos específicos abaixo, considerando suas datas e revisões.

## Implementação recente

- [Correção do contato com o chão](GROUND_CONTACT.md).

## Avaliação atual

- [Mecânicas, balanceamento e critérios de lançamento](GAMEPLAY_RELEASE_REVIEW.md).

## Estado implementado e histórico

- [Escala urbana](CITY_SCALE.md): a seção final registra mapa 256 × 256 m e anel de prédios; o início descreve versão anterior.
- [Cidade e controles](CITY_AND_CONTROLS.md): rotas, pausa, colocação e trânsito; dimensões iniciais são históricas.
- [Personagens modulares](CHARACTERS_MODULAR.md).
- [Moldes de bolso](MOLD_LOADOUT.md).
- [Colocação e iscas](PLACEMENT_AND_DECOYS.md): restrições antigas foram substituídas por CITY_AND_CONTROLS.
- [POC multiplayer](MULTIPLAYER_POC.md).
- [Créditos](../assets/CREDITS.md).
- [Fila histórica](../CODEX_QUEUE.md) e [tarefas históricas](../CODEX_TASKS.md).
- [Validação da publicação](validation/2026-09-21/README.md).

As instruções e documentos do ZeonHub pertencem a outro repositório. O Perfect Ruse não possuía README, índice ou AGENTS.md próprio na inspeção. Este índice organiza os documentos existentes sem importar regras de domínio do ZeonHub.

## Contrato de trabalho

Consultar a issue e suas dependências; ler os documentos afetados; implementar somente o escopo solicitado; atualizar docs e issue com evidências. Regras de partida continuam centralizadas em `main.gd`. Ao alterar layout, executar testes de cidade, rotas, carros, colocação e smoke gráfico. Ao alterar assets, validar contato com superfícies e identidade entre objeto comum, isca e esconderijo. Não fechar tarefa de balanceamento apenas com testes automatizados: registrar playtest.
