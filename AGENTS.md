# AGENTS

Regras de trabalho para agentes neste repositório.

## Linguagem (canônica)

Produto, UI e documentação do Omni devem usar **PT-BR** como linguagem canônica;
termos técnicos internos em inglês só quando forem convenção de framework e **não
devem vazar** para a experiência do usuário.

- Texto de UI, labels, botões, badges, mensagens, títulos, documentação e nomes/comentários
  de teste descritivos: **PT-BR**.
- Nomes técnicos internos (tabela, coluna, enum, classe, model, método, rota técnica,
  chave de símbolo): podem permanecer em inglês por convenção do Rails.
- Quando um valor interno em inglês aparece na tela, expor sempre o **rótulo PT-BR**
  correspondente (ex.: status `open`/`reviewed`/`ignored` → `Aberta`/`Revisada`/`Ignorada`).

Vocabulário canônico de áreas específicas vive na própria documentação da área
(ex.: Triagem em `docs/PB-020_TRIAGEM_CONVERSAS_REQUISITOS.md`).
