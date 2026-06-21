# Omni — Índice da Documentação

> Ponto de entrada da governança do projeto **Omni**. Lista os documentos oficiais, sua função, a **fonte de verdade** por assunto e as regras anti-drift. Mantido em `app/docs/`.

## Visão geral do projeto
Omni unifica o domínio de trabalho (clientes/projetos/tarefas/demandas/apontamentos) com as **conversas de IA** (saída normalizada do pipeline Python externo) numa aplicação **Rails 8 / Hotwire / ViewComponent**, tratando conversas como evidência vinculável a tarefas. O pipeline Python permanece externo e intocado; o Rails consome `output/normalized/` (ADR-007/008) e lê turnos de forma **lazy** por índice de offsets (ADR-021).

**Estado (2026-06-21):** M1/M2 ✅ · M3 🟢 MVP de metadados · M4 🟢 MVP manual · M5 ✅ MVP interno concluído (F5.1 render + F5.1.5 PII + F5.2 markdown + F5.3 criar tarefa + F5.4 lista acionável + F5.5 navegação por âncoras; UI-01/04/09, CV-03/05/06/10, scorer, inbox = roadmap/v1) · M6/M7 ⬜. **Trilha ativa: Produto Operacional** (PB-003 concluída; **PB-015 entregue** — sync operacional de conversas, importação via UI lê `output/normalized/` e **não** dispara o pipeline, ADR-011; **PB-004 concluída** (a/b/c), **PB-005** (`/demands`), **PB-006** (`/clients` Empresas/Contatos + CNPJ por proxy — **ADR-022**) e **PB-007** (`/projects` + duplicação) entregues — **as 4 listas operacionais estão completas** (lacuna operacional da PB-001 fechada); **PB-013a entregue** (busca global na topbar — `GET /search`, agrupada por categoria); **PB-013 segue parcial** (PB-013b: breadcrumbs + preservação de filtros/contexto — pendente). Pendentes: PB-013b, **PB-014** (código legível), **PB-016** (agendador interno) e produção). **F7.1 entregue** (endurecimento de `production.rb` + admin seed), mas **deploy/produção real NUNCA foi exercido**. **Métricas correntes: ver `PROJECT_STATUS.md`** (fonte única; não duplicadas aqui).

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
| [adr/](adr/) | ADRs 001–022 (texto completo) | **Decisões arquiteturais** (cada `ADR-NNN-*.md`) |
| Contratos de fase: [F3_CONTRACT_DECISIONS.md](F3_CONTRACT_DECISIONS.md) · [F4_CONTRACT_DECISIONS.md](F4_CONTRACT_DECISIONS.md) · [F5_CONTRACT_DECISIONS.md](F5_CONTRACT_DECISIONS.md) | Decisões/contrato de cada fase | **Detalhe técnico/contrato** da fase respectiva |
| [UI_COMPLIANCE_AUDIT.md](UI_COMPLIANCE_AUDIT.md) | Régua de conformidade visual | Padrões de UI/hi-fi |
| [PRODUCT_GAP_REVIEW.md](PRODUCT_GAP_REVIEW.md) | Diagnóstico de lacunas de produto | Revisão de paridade operacional TaskManager/Viewer/Mockup/Omni; não autoriza execução por si só |
| [PRODUCT_BACKLOG.md](PRODUCT_BACKLOG.md) | Backlog oficial de produto | Priorização P0/P1/P2/P3, **status/autorização** dos itens (PB-NNN) e fila autorizável |
| Auditorias/contratos de produto: [PB-001_PARITY_AUDIT.md](PB-001_PARITY_AUDIT.md) · [PB-003_TIME_CONTRACT.md](PB-003_TIME_CONTRACT.md) | Auditoria/contrato técnico de itens PB | **Detalhe técnico/contrato** do item PB respectivo |

## Fonte de verdade por assunto (resumo)
- **Decisão arquitetural:** o `ADR-NNN` específico → indexado em `ARCHITECTURE_DECISIONS_INDEX.md`.
- **Status macro (fase/marco):** `ROADMAP.md`.
- **Status granular (feature):** `FEATURE_MATRIX.md`.
- **Status/autorização de item de produto (PB):** `PRODUCT_BACKLOG.md`.
- **Contrato técnico de uma fase / item PB:** `F{n}_CONTRACT_DECISIONS.md` / `PB-NNN_*.md`.
- **Estado atual / semáforos / readiness / métricas correntes:** `PROJECT_STATUS.md` (**fonte única das métricas**; demais docs referenciam, não duplicam).
- **Histórico de entregas:** `DELIVERY_LOG.md` (append-only; não reescrever).
- **Fronteiras/restrições:** `CONSTRAINTS.md` (prevalece em conflito de implementação).
- **Conversa de coordenação/PO (outro chat) NÃO é fonte permanente:** decisões aprovadas só valem quando registradas nos docs oficiais acima.

## Ordem de atualização (condicional — atualizar só o que mudou)
- **`ADR` + `ARCHITECTURE_DECISIONS_INDEX`:** somente quando houver **decisão arquitetural**.
- **Contrato (`F{n}_CONTRACT` / `PB-NNN_*`):** somente quando o **contrato/escopo daquele item** mudar.
- **`PRODUCT_BACKLOG`:** para **autorização/status** de item de produto (PB).
- **`FEATURE_MATRIX`:** para **status granular** de feature.
- **`MIGRATION_PLAN`:** somente se afetar **dados/estratégia de migração**.
- **`ROADMAP`:** somente se **marco/fase** mudar.
- **`DELIVERY_LOG`:** **append-only**, a cada entrega real (nunca reescrever histórico).
- **`PROJECT_STATUS`:** **sempre por último** (consolida estado/métricas correntes).

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
5. Nenhum item de produto deve ser executado por agente sem estar registrado no `PRODUCT_BACKLOG.md` e autorizado explicitamente pelo Product Owner.

## Topologia de repositórios (onde os docs oficiais vivem)
- **Repositório único e oficial:** `app/` (produto Rails + governança em **`app/docs/`**) — ADR-019.
- `_origem/` (RepoA/RepoB) e `_mockup/` são **somente leitura** (referência), fora do repo — ADR-007/008, `CONSTRAINTS.md`.
- ⚠️ **Atenção (drift):** a raiz legada `c:\Sandbox\_omni` mantém um `.git` antigo e pode conter cópias **desatualizadas** de `docs/` (ex.: ADRs 001–017 do baseline). **A fonte de verdade é `app/docs/`** — ignore qualquer cópia fora de `app/`.
