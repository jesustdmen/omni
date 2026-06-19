# Omni — Índice da Documentação

> Ponto de entrada da governança do projeto **Omni**. Lista os documentos oficiais, sua função, a **fonte de verdade** por assunto e as regras anti-drift. Mantido em `app/docs/`.

## Visão geral do projeto
Omni unifica o domínio de trabalho (clientes/projetos/tarefas/demandas/apontamentos) com as **conversas de IA** (saída normalizada do pipeline Python externo) numa aplicação **Rails 8 / Hotwire / ViewComponent**, tratando conversas como evidência vinculável a tarefas. O pipeline Python permanece externo e intocado; o Rails consome `output/normalized/` (ADR-007/008) e lê turnos de forma **lazy** por índice de offsets (ADR-021).

**Estado (2026-06-19):** M1/M2 ✅ · M3 🟢 MVP de metadados · M4 🟢 MVP manual · M5 ✅ MVP interno concluído (F5.1 render + F5.1.5 PII + F5.2 markdown + F5.3 criar tarefa + F5.4 lista acionável + F5.5 navegação por âncoras; UI-01/04/09, CV-03/05/06/10, scorer, inbox = roadmap/v1) · M6/M7 ⬜. Produção (F7) **não exercida** — ver readiness no `PROJECT_STATUS.md`. Suíte: 274/1068/0.

## Documentos oficiais
| Documento | Função | Fonte de verdade para |
|---|---|---|
| [INDEX.md](INDEX.md) | Este índice / mapa da documentação | Onde encontrar cada assunto; regras anti-drift |
| [CONSTRAINTS.md](CONSTRAINTS.md) | Restrições e fronteiras (referência vs produto) | **Fronteiras** (`_origem/`/`_mockup/` read-only; produto em `app/`); topologia de repositório |
| [ROADMAP.md](ROADMAP.md) | Fases, marcos e critérios de conclusão | **Fases/Marcos** (status macro M0–M7) |
| [MIGRATION_PLAN.md](MIGRATION_PLAN.md) | Plano de migração/estratégia de dados | Estratégia de migração/import (planejamento) |
| [FEATURE_MATRIX.md](FEATURE_MATRIX.md) | Matriz de features (WD/CV/LK/UI/OP/GOV) | **Status por feature** (granular) |
| [DELIVERY_LOG.md](DELIVERY_LOG.md) | Diário de entregas (append-only) | **Histórico** do que foi entregue (snapshots) |
| [PROJECT_STATUS.md](PROJECT_STATUS.md) | Status consolidado + readiness | **Estado atual** (semáforos, próxima decisão, readiness de produção) |
| [ARCHITECTURE_DECISIONS_INDEX.md](ARCHITECTURE_DECISIONS_INDEX.md) | Índice dos ADRs | **Quais ADRs existem** e seus status |
| [adr/](adr/) | ADRs 001–021 (texto completo) | **Decisões arquiteturais** (cada `ADR-NNN-*.md`) |
| Contratos de fase: [F3_CONTRACT_DECISIONS.md](F3_CONTRACT_DECISIONS.md) · [F4_CONTRACT_DECISIONS.md](F4_CONTRACT_DECISIONS.md) · [F5_CONTRACT_DECISIONS.md](F5_CONTRACT_DECISIONS.md) | Decisões/contrato de cada fase | **Detalhe técnico/contrato** da fase respectiva |
| [UI_COMPLIANCE_AUDIT.md](UI_COMPLIANCE_AUDIT.md) | Régua de conformidade visual | Padrões de UI/hi-fi |

## Fonte de verdade por assunto (resumo)
- **Decisão arquitetural:** o `ADR-NNN` específico → indexado em `ARCHITECTURE_DECISIONS_INDEX.md`.
- **Status macro (fase/marco):** `ROADMAP.md`.
- **Status granular (feature):** `FEATURE_MATRIX.md`.
- **Estado atual / semáforos / readiness:** `PROJECT_STATUS.md`.
- **Histórico de entregas:** `DELIVERY_LOG.md` (não reescrever).
- **Fronteiras/restrições:** `CONSTRAINTS.md` (prevalece em conflito de implementação).
- **Contrato técnico de uma fase:** `F{n}_CONTRACT_DECISIONS.md`.

## Ordem de atualização (a cada entrega/decisão)
`ARCHITECTURE_DECISIONS_INDEX` → `ROADMAP` → `MIGRATION_PLAN` → `FEATURE_MATRIX` → `DELIVERY_LOG` → `PROJECT_STATUS` (**sempre por último**). *(Espelha a "Governança da documentação" do `PROJECT_STATUS.md`.)*

## Gatilhos de atualização
- **A cada entrega real:** `DELIVERY_LOG` + `FEATURE_MATRIX` + `PROJECT_STATUS` (e `ROADMAP` se fechou marco).
- **A cada decisão arquitetural:** novo `adr/ADR-NNN-*.md` + `ARCHITECTURE_DECISIONS_INDEX` + `PROJECT_STATUS`.
- **A cada mudança de escopo:** `FEATURE_MATRIX` + `ROADMAP` + `PROJECT_STATUS` (e `MIGRATION_PLAN` se afeta dados/estratégia).
- **Contrato de fase nova:** `F{n}_CONTRACT_DECISIONS.md` + `INDEX`.

## Histórico vs estado atual
- **`DELIVERY_LOG.md` é append-only e imutável:** entradas são **snapshots** do momento (ex.: "221/776" numa entrega passada permanece como foi). **Não reescrever** evidência histórica; para corrigir/atualizar, **adicionar nova entrada/nota**.
- **Estado atual** vive em `PROJECT_STATUS.md`/`FEATURE_MATRIX.md`/`ROADMAP.md` — esses **devem** ser atualizados para refletir o presente (ex.: métricas atuais, semáforos).
- Reverter um ADR = **novo ADR que Substitui** (não editar o original; marcar o antigo como "Substituído"). Esclarecimentos = **addendum** (ex.: addendum do ADR-013).

## Regra anti-drift
1. Cada fato tem **uma** fonte de verdade (tabela acima); os demais docs **referenciam**, não duplicam o valor.
2. Métricas de estado (testes, contagens) ficam no `PROJECT_STATUS`; outros docs citam "ver PROJECT_STATUS" em vez de repetir números que envelhecem.
3. Status de feature só em `FEATURE_MATRIX`; status de fase só em `ROADMAP`; ambos devem concordar com o `PROJECT_STATUS`.
4. Ao tocar qualquer doc, conferir este `INDEX` e os gatilhos acima.

## Topologia de repositórios (onde os docs oficiais vivem)
- **Repositório único e oficial:** `app/` (produto Rails + governança em **`app/docs/`**) — ADR-019.
- `_origem/` (RepoA/RepoB) e `_mockup/` são **somente leitura** (referência), fora do repo — ADR-007/008, `CONSTRAINTS.md`.
- ⚠️ **Atenção (drift):** a raiz legada `c:\Sandbox\_omni` mantém um `.git` antigo e pode conter cópias **desatualizadas** de `docs/` (ex.: ADRs 001–017 do baseline). **A fonte de verdade é `app/docs/`** — ignore qualquer cópia fora de `app/`.
