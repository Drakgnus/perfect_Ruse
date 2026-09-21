# Evidência da base publicada — 21/09/2026

Execução real na máquina do autor, sem alterações nos scripts ou cenas:

`python tools/run_character_checks.py game-1200 visual-smoke`

- game-1200: PASS, exit 0, 1.200 frames.
- visual-smoke: PASS, exit 0, 180 frames medidos, média 60,0 FPS, 64 civis.
- Captura gameplay-characters.png inspecionada para escala e leitura geral.

A amostra gráfica é curta e pode estar limitada por sincronização; não é benchmark nem aceite de perseguição. O teste reposiciona três civis para captura e não mede distância dos pés/rodas. Não foi executada nesta entrega a suíte completa de regressão nem playtest humano.

Logs e captura foram copiados da execução para esta pasta. Não confundir estes resultados com validações históricas em outros documentos.

Verificação pré-publicação: nenhum arquivo de projeto acima de 100 MB; busca por padrões de tokens GitHub/OpenAI e chaves privadas sem correspondências nos arquivos textuais selecionados. Essa busca limitada não é uma auditoria completa. Caches, perfis e downloads temporários não entram no Git.

Ocorrências operacionais: Git inicialmente não reconheceu a pasta porque `.git` estava vazia; inicializar sem histórico a sobrescrever. Consulta GitHub bloqueada no sandbox passou com execução de rede autorizada. Primeira expressão de busca de segredos falhou por aspas PowerShell; repetida com Python e padrões explícitos, sem correspondências. Nenhuma dessas tentativas alterou gameplay.
