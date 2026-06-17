# Omni/Continuity — Índice de Decisões Arquiteturais (ADRs)

> **Todos os ADRs em status Aceito desde 2026-06-16.** O texto completo de cada ADR está em `docs/adr/ADR-NNN-*.md`. Reverter uma decisão = criar novo ADR que **Substitui** o anterior (não editar o original; marcar o antigo como "Substituído").

| ADR | Título | Status | Aprovado em | Fase | Impacto | Dependências | Validação futura |
|---|---|---|---|---|---|---|---|
| ADR-001 | Rails monólito + Hotwire | ✅ Aceito | 2026-06-16 | 1 | Alto | 002 | — |
| ADR-002 | Sem React no MVP (ilhas futuras) | ✅ Aceito | 2026-06-16 | 5 | Médio | 001 | reavaliar render de conversa com protótipo (F5) |
| ADR-003 | Devise (auth) | ✅ Aceito | 2026-06-16 | 1 | Alto | 004,014 | teste real de login com hash migrado |
| ADR-004 | Pundit (authz) | ✅ Aceito | 2026-06-16 | 1 | Médio | 013,014 | — |
| ADR-005 | Solid Queue (jobs) | ✅ Aceito | 2026-06-16 | 1 | Médio | 009,011 | — |
| ADR-006 | PostgreSQL 16 | ✅ Aceito | 2026-06-16 | 1 | Alto | 005,009 | — |
| ADR-007 | Pipeline Python externo (MVP) | ✅ Aceito | 2026-06-16 | 3 | Alto | 008 | — |
| ADR-008 | Consumo `output/normalized/` | ✅ Aceito | 2026-06-16 | 3 | Alto | 007,009 | — |
| ADR-009 | Turnos lazy/sob demanda | ✅ Aceito | 2026-06-16 | 3 | Alto | 008,010 | mapeamento `thread_id → shards/messages/<sha1>` **refutado** → ver addendum **ADR-018** |
| ADR-010 | Diário por view sob demanda | ✅ Aceito | 2026-06-16 | 6 | Médio | 009 | — |
| ADR-011 | Agendador externo roda; Rails lê | ✅ Aceito | 2026-06-16 | 3/6 | Médio | 005 | disparo do pipeline pelo Rails só com allowlist+timeout+path fixo |
| ADR-012 | Sanitização server-side de markdown | ✅ Aceito | 2026-06-16 | 5 | Alto (XSS) | — | teste de payload malicioso (F5) |
| ADR-013 | Conversas pessoais (`personal`+`user_id`+Pundit) | ✅ Aceito | 2026-06-16 | 3/5 | Médio | 004,014 | reavaliar cifra se multiusuário real |
| ADR-014 | Multiusuário preparado; domínio compartilhado MVP | ✅ Aceito | 2026-06-16 | 1/3 | Médio | 004,013 | tenancy de domínio → roadmap |
| ADR-015 | Dropar runtime-switch de ambiente | ✅ Aceito | 2026-06-16 | 1/2 | Médio | 006 | homologação = ambiente separado; clone = rake task segura |
| ADR-016 | Task MVP = paridade + counters | ✅ Aceito | 2026-06-16 | 2 | Médio | — | tags/assignee/due_date/estimated_hours/checklist/código → v1 |
| ADR-017 | CNPJ nullable + partial unique | ✅ Aceito | 2026-06-16 | 2 | Baixo | — | normalizar `''`→NULL na migração |
| ADR-018 | Addendum ao ADR-009 — shards por arquivo-fonte; turnos lazy fora da F3 | ✅ Aceito | 2026-06-17 | 3 | Médio | 009,008 | decidir índice `thread_id→offset/shard` antes da F5 |
| ADR-019 | Consolidação em repositório único (`app/`) + docs em `app/docs/` | ✅ Aceito | 2026-06-17 | 3 | Médio | — | configurar remoto único e primeiro push |
| ADR-020 | Exceção read-only para `workspaceStorage` (resolução de folders) | ✅ Aceito | 2026-06-17 | 3 | Médio | 008,007 | remover se RepoB emitir `workspace_maps.json` normalizado |

## Manutenção
- Ao aceitar um ADR: mudar Status para **Aceito** e preencher *Aprovado em*.
- Ao reverter: criar novo ADR (**Substitui** o anterior), marcar o original como **Substituído**, registrar em `DELIVERY_LOG.md` e `PROJECT_STATUS.md`.
