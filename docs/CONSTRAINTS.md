# Omni — Restrições e Fronteiras do Projeto

> **Documento oficial e permanente.** Define quais diretórios são *referência* (somente leitura) e qual é o *produto*. Vale para todas as fases. Em conflito com qualquer outra instrução de implementação, esta fronteira prevalece.

## Propósito
Evitar que material de referência (apps legados e mockup) seja tratado como fonte de código do produto. A implementação do Omni é **nova, do zero**, em `app/`, respeitando os ADRs aceitos. Referências servem para extrair *requisitos e comportamento*, nunca para copiar *código, assets ou arquivos*.

## Regra permanente
**`_origem/` e `_mockup/` são SOMENTE LEITURA.** Não editar, não formatar, não aplicar patch, não commitar, não criar nem remover arquivos dentro desses diretórios. O produto é construído exclusivamente em `app/`.

## Quadro de fontes

| Diretório | Papel | Editar? | Copiar p/ o produto? |
|---|---|---|---|
| `_origem/_repoa` | Referência de **domínio/schema/comportamento legado** (TaskManager TS) | ❌ | ❌ sem aprovação explícita |
| `_origem/_repob` | Referência de **pipeline/contrato/normalização** (Python; saída `output/normalized/`) | ❌ | ❌ sem aprovação explícita |
| `_mockup` | Referência **visual/funcional/de fluxo** (wireframes e specs JSX) | ❌ | ❌ sem aprovação explícita |
| `docs/` | **Governança** — fonte oficial de decisões (ADRs, roadmap, status); **vive dentro do app** (`app/docs/`) | ✅ | — |
| `app/` | **Produto + governança** — app Rails novo (Rails/Hotwire/ViewComponent) + `docs/` | ✅ | — |

## Topologia de repositórios (consolidada — ver ADR-019)
- **`app/` é o repositório Git único e principal do projeto.** Contém a aplicação Rails (produto) **e** a governança em **`app/docs/`** (ADRs, roadmap, status). A toolchain de dev (imagem Docker) vive em `app/.devstack/`.
- **A raiz `c:\Sandbox\_omni`** deixou de ser repositório de produto: é apenas **pasta local de trabalho/histórico**. Seu `.git` antigo é mantido como **arquivo histórico** (não apagado), mas **não recebe mais commits**.
- `_origem/` e `_mockup/` permanecem **fora** do repositório do app (irmãos de `app/`), **somente leitura** e **não versionados**.
- Histórico anterior: até 2026-06-17 havia dois repositórios (app + raiz/docs); a consolidação está registrada no **ADR-019**.

## O que É permitido extrair das referências
- Requisitos e telas esperadas.
- Fluxos de navegação e atalhos.
- Regras de negócio e comportamento esperado (vínculo, triagem, diário, handoff, settings).
- Critérios de aceite.
- Nomenclatura funcional.
- Contrato de dados do pipeline (campos do schema canônico).

## O que é PROIBIDO sem aprovação explícita
- Copiar código.
- Copiar componentes (ex.: JSX do mockup).
- Copiar assets.
- Copiar arquivos.
- Aplicar patch em `_origem/`.
- Aplicar patch em `_mockup/`.
- Importar dados (de bancos legados ou do pipeline) fora da fase/escopo aprovados.
- Alterar qualquer repositório de referência.

## Gatilho de parada
Se em qualquer fase surgir a necessidade de **copiar código, assets, lógica ou arquivo** de um diretório de referência, **PARAR imediatamente e pedir autorização explícita** antes de prosseguir. Nunca fazer por iniciativa própria.

## Relação com os ADRs
- **ADR-001** — implementação do produto em Rails/Hotwire/ViewComponent (não SPA, não cópia de JSX do mockup).
- **ADR-007 / ADR-008** — pipeline Python permanece **externo**; o produto consome **somente `output/normalized/`**, sem reparsear bruto nem importar o código do RepoB.
- **ADR-016** — escopo MVP controlado: implementar só o que a fase aprova; referências não ampliam escopo por conta própria.

> Ver índice de decisões em [ARCHITECTURE_DECISIONS_INDEX.md](ARCHITECTURE_DECISIONS_INDEX.md) e estado atual em [PROJECT_STATUS.md](PROJECT_STATUS.md).
