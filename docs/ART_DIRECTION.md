# Direção visual e catálogo copiável

Data: 21/09/2026. Proposta para execução futura.

## Referência

O personagem modular chibi do autor é a referência de proporção e acabamento. Buscar objetos mais reconhecíveis, detalhados e variados, com materiais coerentes, evitando a mistura casual de realismo fotográfico com boneco estilizado. O pedido atual revisa a restrição histórica de manter exclusivamente o visual Kenney/cores chapadas em CODEX_TASKS; não autoriza trocar todo o jogo nesta etapa. Uso de texturas/PBR deve ser decidido por amostra comparativa, desempenho e leitura na câmera real.

Primeiro montar uma pequena cena com personagem, porta, trecho de fachada, um carro e 6–8 objetos. Comparar no mesmo enquadramento e luz. Aprovar linguagem de forma, escala, contraste, textura e sombras antes de migração ampla. Avaliar limitações do renderizador `gl_compatibility` utilizado, sem presumir que ativar uma opção de efeito produz o resultado desejado.

## Objetos para explorar

Catálogo atual: barril, caixa, vaso, pedra, tronco, cone e arbusto. Meta inicial de investigação: 12–16 tipos totais, sem compromisso de integrar todos. Candidatos urbanos: lixeira pequena, saco de lixo, caixa plástica, caixa de papelão, engradado, balde, palete, pneu e equipamento de serviço. Objetos grandes (caçamba, banco, armário técnico) só depois de testar oclusão, colisão, colocação e custo de inspeção.

Distribuir por contexto: caixas junto a comércio/entrega, recipientes e lixeiras em acessos de serviço, vasos em fachadas, elementos naturais em praça/parque. Adicionar variantes visuais não pode criar uma assinatura exclusiva do esconderijo.

## Requisitos para seleção e download

- Pesquisar fontes e packs no momento da implementação; não há pack comprado, baixado ou aprovado nesta análise.
- Preferir formato importável como GLB/glTF, escala/pivô documentados e texturas completas; medir complexidade no Godot.
- Registrar URL exata, autor, versão/data, licença, permissões de redistribuição dos arquivos no repositório público e atribuição; uso em jogo não implica direito de publicar fontes do pack.
- Definir materiais e textura de forma consistente; evitar baixar centenas de assets sem triagem.
- Medir tamanho visual e colisão por objeto. Calibrar pivot de apoio e normais de colocação em chão/parede/teto, inclusive após giro.
- Mesmo asset, materiais, escala, sombras e fábrica para cenário, isca e esconderijo. Sem brilho, contorno, sombra ou qualidade de textura exclusivos que denunciem o dinheiro.
- Preservar limite de três moldes de bolso, cópia na rua, roda radial, rótulos, persistência, cancelamento e inspeção de 1,6 s. Novos identificadores precisam de migração/fallback para saves antigos.
- Testar variedade pelo custo para ambos os lados: esconder não pode depender de um único objeto ótimo, e o policial não deve precisar revistar centenas de objetos indistintos sem pistas.

## Prédios e carros

Prédios: kit modular com fachadas contíguas, peças de esquina e fundos; portas/andares na escala do personagem; ornamentos não criam frestas e colisões invisíveis. Evitar reconstruir lotes para caber num pack adquirido cedo demais.

Carros: escolher acabamento compatível, dimensões que preservem pistas/vagas, rodas com apoio mensurável, orientação/pivô consistentes. Substituição não altera por acidente roubo, semáforo ou freio para pedestres.

## Aceite visual e técnico

Comparativo antes/depois na câmera real e close-up de apoio; validação de importação, rotas, colocações, identidade visual de isca/objeto e uso de memória. Medir frames medianos e p95 em trajeto repetível com população/trânsito iguais. A amostra atual de 60 FPS não demonstra margem de GPU/CPU; não usar como orçamento garantido. Registrar perdas de desempenho e a decisão tomada antes de aumentar densidade ou resolução.

## Personagens: avaliação autorizada pelo autor

Complemento de 21/09/2026: o autor permite sugerir melhorias nos personagens se ajudarem o tema; se a base atual fizer sentido, deve ser mantida. Avaliação inicial: preservar o chibi modular como referência, pois roupa/acessórios e silhuetas legíveis sustentam o disfarce. É uma recomendação preliminar, não uma proibição de evoluir o boneco.

Na amostra de arte, comparar proporções, mãos/pés, acabamento de roupa/cabelo, animações e contato com o chão. Sugerir primeiro ajustes localizados; propor remodelagem completa apenas com comparação que demonstre ganho de coerência e leitura. Não há autorização implícita para implementar a troca nesta tarefa de planejamento.

Qualquer evolução futura preserva rig/clipes ou prevê migração explícita, acessórios combináveis, uniforme policial reservado, identidade visual compartilhada por civil/ladrão, cópia de roupa, versão despida e conversão. A decisão pode ser manter o personagem sem alteração, com justificativa registrada.
