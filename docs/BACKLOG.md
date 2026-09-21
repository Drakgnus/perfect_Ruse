# Backlog oficial — 21/09/2026

O GitHub Issues é a fonte de acompanhamento desta evolução. As filas CODEX antigas são histórico. A consulta inicial encontrou o repositório vazio e nenhuma issue; o Project existente consultado pertence ao ZeonHub e não foi alterado.

Épico: [Planejar bairro compacto, perseguição justa e evolução visual](https://github.com/Drakgnus/perfect_Ruse/issues/1).

| Issue | Dependências | Estado |
|---|---|---|
| [#2 — Corrigir apoio de personagens e veículos nas superfícies](https://github.com/Drakgnus/perfect_Ruse/issues/2) | — | Concluído; ver [evidência](GROUND_CONTACT.md) |
| [#3 — Prototipar quadras retangulares, fachadas contínuas e becos de serviço](https://github.com/Drakgnus/perfect_Ruse/issues/3) | #2 | Planejado |
| [#4 — Adaptar navegação, polícia, trânsito e minimapa ao bairro compacto](https://github.com/Drakgnus/perfect_Ruse/issues/4) | #3 | Planejado |
| [#5 — Validar tamanho do bairro e equilíbrio das perseguições](https://github.com/Drakgnus/perfect_Ruse/issues/5) | #3, #4 | Planejado |
| [#6 — Validar direção visual compatível com o personagem chibi](https://github.com/Drakgnus/perfect_Ruse/issues/6) | #2 | Planejado |
| [#9 — Avaliar personagem no tema e propor ajustes somente se necessários](https://github.com/Drakgnus/perfect_Ruse/issues/9) | #6 | Planejado |
| [#7 — Ampliar e melhorar catálogo de objetos copiáveis](https://github.com/Drakgnus/perfect_Ruse/issues/7) | #6, #9, #5 | Planejado |
| [#8 — Harmonizar prédios e carros com a nova direção visual](https://github.com/Drakgnus/perfect_Ruse/issues/8) | #7, #5, #9 | Planejado |

Contato com o chão concluído. Após a avaliação de gameplay, a próxima implementação recomendada é #11 (percepção policial), seguida das decisões #12/#13 antes de balancear. Layout começa isolado; integração final exige navegação. A amostra visual pode avançar após apoio correto; catálogo entra após avaliar personagem e escala do bairro. Avaliar personagem não significa substituí-lo: manter a base é um resultado válido.

Nesta entrega foram concluídos análise, documentação, organização das issues e preparação da base para GitHub. A issue #2 foi implementada após autorização posterior; as demais melhorias permanecem pendentes. Não fechar o épico pela simples criação das issues.

Antes de cada implementação: ler README/índice, issue e documentos específicos; verificar dependências; atualizar docs e issue; registrar testes apropriados e smoke para mudanças importantes. Balanceamento exige playtest além de testes técnicos.

## Avaliação de gameplay e lançamento — solicitação posterior

[Análise completa](GAMEPLAY_RELEASE_REVIEW.md). As melhorias abaixo estão planejadas, não implementadas. Corrigir percepção/informação/objetivo antes de tratar taxas de vitória como evidência de balanceamento e antes de investir na migração ampla de assets.

- [#10 — Avaliar prontidão e preparar teste fechado de Perfect Ruse](https://github.com/Drakgnus/perfect_Ruse/issues/10)
- [#11 — [P0] Tornar percepção policial coerente com frente visual e pistas observáveis](https://github.com/Drakgnus/perfect_Ruse/issues/11)
- [#12 — [P0] Preservar camuflagem na inspeção de objetos e na IA](https://github.com/Drakgnus/perfect_Ruse/issues/12)
- [#13 — [P0] Validar objetivo, economia e encerramento da rodada](https://github.com/Drakgnus/perfect_Ruse/issues/13)
- [#14 — [P1] Revisar informação por equipe e utilidade das habilidades](https://github.com/Drakgnus/perfect_Ruse/issues/14)
- [#15 — Preparar build distribuível e definir escopo de rede do primeiro teste](https://github.com/Drakgnus/perfect_Ruse/issues/15)
