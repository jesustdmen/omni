# Omni — Índice de Decisões Arquiteturais (ADRs)

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
| ADR-009 | Turnos lazy/sob demanda | ✅ Aceito | 2026-06-16 | 3 | Alto | 008,010 | mapeamento `thread_id → shards/messages/<sha1>` **refutado** → ver addendum **ADR-018**; estratégia definida em **ADR-021** (índice de offsets) |
| ADR-010 | Diário por view sob demanda | ✅ Aceito | 2026-06-16 | 6 | Médio | 009 | — |
| ADR-011 | Agendador externo roda; Rails lê | ✅ Aceito (+addenda 2026-06-21, 2026-06-22 e 2026-06-28) | 2026-06-16 | 3/6 | Médio | 005 | **PB-015** (Rails só lê) + **PB-016 concluída em dev/local**: Omni dispara o pipeline via **agente no host** (não no container), com allowlist+timeout+token+sem input; agendamento interno em /settings. **Addendum 2026-06-28:** RepoB é referência **não produtiva** (ausente em prod); o agente que roda `run_pipeline.py` do RepoB é **andaime de dev**; origem produtiva de coleta/normalização **a definir** (F7.7) |
| ADR-012 | Sanitização server-side de markdown | ✅ Aceito | 2026-06-16 | 5 | Alto (XSS) | — | teste de payload malicioso (F5) |
| ADR-013 | Conversas pessoais (`personal`+`user_id`+Pundit) | ✅ Aceito | 2026-06-16 | 3/5 | Médio | 004,014 | impl. usa coluna boolean `personal` (sem `status`) + decisão b1 (ver addendum F5.1.2 no ADR-013); reconciliar ao implementar b2/cifra |
| ADR-014 | Multiusuário preparado; domínio compartilhado MVP | ✅ Aceito | 2026-06-16 | 1/3 | Médio | 004,013 | tenancy de domínio → roadmap |
| ADR-015 | Dropar runtime-switch de ambiente | ✅ Aceito | 2026-06-16 | 1/2 | Médio | 006 | homologação = ambiente separado; clone = rake task segura |
| ADR-016 | Task MVP = paridade + counters | ✅ Aceito (+addendum 2026-06-22) | 2026-06-16 | 2 | Médio | — | checklist (PB-004b) e código legível `TSK-000001` (PB-014) reabertos/entregues; tags/assignee/due_date/estimated_hours → v1 |
| ADR-017 | CNPJ nullable + partial unique | ✅ Aceito | 2026-06-16 | 2 | Baixo | — | normalizar `''`→NULL na migração |
| ADR-018 | Addendum ao ADR-009 — shards por arquivo-fonte; turnos lazy fora da F3 | ✅ Aceito | 2026-06-17 | 3 | Médio | 009,008 | índice `thread_id→offset` definido em **ADR-021** |
| ADR-019 | Consolidação em repositório único (`app/`) + docs em `app/docs/` | ✅ Aceito | 2026-06-17 | 3 | Médio | — | configurar remoto único e primeiro push |
| ADR-020 | Exceção read-only para `workspaceStorage` (resolução de folders) | ✅ Aceito | 2026-06-17 | 3 | Médio | 008,007 | remover se RepoB emitir `workspace_maps.json` normalizado |
| ADR-021 | Lazy-load de turnos via índice de offsets em `sessions.jsonl` | ✅ Aceito | 2026-06-17 | 5 | Alto | 009,018,008,012,013 | implementar índice (`conversation_turn_refs`) + fingerprint na fatia pré-F5 |
| ADR-022 | Consulta de CNPJ: proxy no Rails → **revertida p/ navegador** | ↩️ Revertida (addendum 2026-06-23) | 2026-06-21 | PB-006 | Médio | 011 | proxy removido: IP do container era rate-limitado (429); consulta volta ao navegador (IP do usuário, como RepoA); host fixo no cliente |
| ADR-023 | Timezone operacional = Brasília; banco persiste UTC | ✅ Aceito | 2026-06-23 | timezone | Médio | — | `config.time_zone="Brasilia"` + `default_timezone=:utc`; parse de datetime-local e `date` de TimeEntry em Brasília; impacta horas/Fechamentos/Relatórios; sem backfill |
| ADR-024 | Status configurável (Tarefas/Projetos) com FK composta | ✅ Aceito | 2026-06-24 | PB-018 | Médio | 016 | tabela `configurable_statuses` (entity_type,key,name,color,position,active,final); `status` segue string/key; FK composta `(status_entity,status)→(entity_type,key)` ON DELETE RESTRICT; CHECKs fixos removidos; Demanda fixa; `final` só visual |
| ADR-025 | Empresa Prestadora + Contratos (frente comercial) | ✅ Aceito (+addendum 2026-06-24: Apuração × Precificação) | 2026-06-24 | PB-019 | Alto | 023 | novas `provider_companies` e `contracts` (prestadora+cliente, projeto opcional, prioridade projeto>cliente); só `hourly`+`hourly_rate` decimal; status enum fixo (draft/active/suspended/ended); **apuração de horas independe de contrato** (contrato = precificação; horas sem contrato visíveis); fluxo Apuração→Validação→Precificação→Fechamento(snapshot)→Relatório; TimeEntry não grava valor/contrato; sobreposição validada em Rails (EXCLUDE/btree_gist futuro); UI Prestadora em Configurações, Contratos na sidebar; não renomear Client→Empresa |

## Manutenção
- Ao aceitar um ADR: mudar Status para **Aceito** e preencher *Aprovado em*.
- Ao reverter: criar novo ADR (**Substitui** o anterior), marcar o original como **Substituído**, registrar em `DELIVERY_LOG.md` e `PROJECT_STATUS.md`.
