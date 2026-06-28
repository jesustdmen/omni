# Relatório — Saneamento documental (docs-only)

| Campo | Valor |
|---|---|
| Data | 25-06-2026 |
| Assunto | Saneamento documental — reconciliação da governança com a entrega da Triagem (PB-020) e da IA local |
| Papel | Executor (`omni-executar`) |
| Escopo | Somente documentação (`docs/*.md`); sem código/schema/migrations/testes |
| Gate | Concluído **sem commit/push** (aguardando autorização) |
| Repo | `C:/Sandbox/_omni/app` (repo externo `_omni` não tocado) |

> Regra de ouro aplicada: nenhuma afirmação de entrega sem evidência (commit/código/migration/teste). Pendências reais mantidas explícitas, não suavizadas.

## 1. Arquivos alterados (todos por mim — só docs de produto)
- `docs/DELIVERY_LOG.md`
- `docs/PROJECT_STATUS.md`
- `docs/FEATURE_MATRIX.md`
- `docs/ROADMAP.md`
- `docs/PRODUCT_BACKLOG.md`
- `docs/PB-020_TRIAGEM_CONVERSAS_REQUISITOS.md`
- `docs/INDEX.md`

(Este relatório, `docs/relatorios/25-06-2026-Saneamento-Documental-Executor.md`, é um novo artefato criado a pedido do PO.)

## 2. Resumo das correções
- **DELIVERY_LOG:** 2 entradas novas no topo (append-only) — (a) IA local Ollama/Gemma4; (b) Triagem persistida mínima + criar/vincular + atividades de 2º nível. Com commits, evidência de testes e escopo negativo. **Sem** claim de produção/aceite operacional.
- **PROJECT_STATUS:** snapshot → 2026-06-25; "última entrega" agora é a trilha Triagem+IA (`68e9e8c`→`de58b7e`, suíte 889/0); "próxima ação" reescrita (próximos passos da Triagem + aceite PB-020a); semáforo de UI cita a Triagem parcial.
- **FEATURE_MATRIX (UI-05):** removidas as afirmações falsas ("Ainda NÃO há estado persistido/atividades/IA"); listado o que foi entregue e o que segue pendente.
- **ROADMAP:** Fase 6 e M6 de "⬜ Não iniciada" → **🟡 Em progresso (parcial)** com entregue × pendente.
- **PRODUCT_BACKLOG:** nota esclarecendo que **PB-020 tem duas frentes** (produto/Triagem entregue × comercial/tempo a/b/c); §7 corrigida (PB-020a aceite pendente; b/c/021/022 não iniciadas; Triagem entregue); removido o pedido obsoleto de "autorizar PB-020a".
- **PB-020_TRIAGEM:** notas de **ATUALIZAÇÃO** marcando como implementado o que era "futuro/não implementado" (decisão persistida, atividades, IA), preservando o texto original como especificação.
- **INDEX:** data do estado → 2026-06-25 + M6 parcial; **adicionados à tabela** os specs `PB-020_TRIAGEM` e `ia_local_ollama_gemma4_api`.

## 3. Contradições encontradas e resolução
| # | Contradição | Resolução |
|---|---|---|
| 1 | PROJECT_STATUS: "última entrega = PB-019a" e "próxima = autorizar PB-020a", mas Triagem+IA foram commitados/pushados depois | Atualizado última/próxima/semáforo + snapshot |
| 2 | FEATURE_MATRIX UI-05: "Ainda NÃO há estado persistido / atividades 2º nível / IA-Gemma" | Reescrito: entregue vs pendente, com evidência de commits |
| 3 | ROADMAP Fase 6/M6 "⬜ Não iniciada" | → 🟡 parcial |
| 4 | PRODUCT_BACKLOG: "PB-020 não iniciadas" contradizia a própria PB-020a (implementada) e omitia a Triagem | Separado PB-020a (aceite pendente) de b/c (não iniciadas) + nota da frente de Triagem entregue |
| 5 | PB-020 doc: "não existe ainda" / "Nao implementado" / "nada de Ollama implementado" | Notas ATUALIZAÇÃO marcando implementado; spec original preservado |
| 6 | INDEX defasado (2026-06-22) e sem links para specs PB-020/IA | Data/M6 atualizados + 2 specs adicionados à tabela |

## 4. Pendências que continuam reais (mantidas explícitas)
- **Frente de tempo da Triagem (não iniciada):** classificação de gaps, validação de tempo, **rascunho de apontamento**, **promoção a TimeEntry**.
- **Triagem avançada:** cards "Prontas p/ tarefa"/"Gaps a validar", filtros avançados/ordenação/lote/"triar em sequência"/exportar, scorer/auto-link.
- **Comercial:** PB-020b (Validação), PB-020c (Precificação), PB-021 (Fechamento/snapshot), PB-022 (PDF) — todas Aprovadas, não iniciadas.
- **Fase 6 restante:** diário, retenção, handoff externo, workspaces órfãos.
- **Produção (F7):** nunca exercida; **aceite operacional do PO** das fatias Triagem/IA/PB-019b/PB-020a **não registrado**.

## 5. Evidência factual (reconciliação)
Implementado e publicado em `main` (commits + código + migrations + testes verdes), antes ausente/contradito nos docs:

| Entrega | Commit(s) | Evidência de código |
|---|---|---|
| Triagem read-only base (inbox + modo triagem) | `68e9e8c`, `3ae1484` | `/triage`, `?mode=triage` |
| Decisão de triagem persistida mínima | `99bf00f` | migration `20260625120000_create_conversation_triages`, `ConversationTriageDecision`, service `ConversationTriage` |
| Criar/vincular tarefa com contexto | `0e957bf` | fluxo no detalhe de triagem |
| Atividades manuais de 2º nível | `e983a29` | migration `20260625130000_create_conversation_activity_drafts` |
| Núcleo IA local isolado | `18b80e2` | `Ai::OllamaClient`, `Ai::SuggestConversationActivities` |
| IA extrai do conteúdo real + integração | `de58b7e` | `Ai::ConversationContextBuilder` (LazyLoader/ADR-021 + PiiRedactor); migration `20260625150000` (CHECK `source` → `manual|ia_local`) |
| Correção do contrato da API nativa Ollama | `f96ace9` | `docs/ia_local_ollama_gemma4_api.md` |

## 6. Comandos de validação executados (via Docker `omni-rails-dev` + `omni_db`)
- `bin/rails test` → **889 runs / 3299 assertions / 0 falhas / 0 erros / 0 skips** (confirma que nenhum código foi tocado pela rodada docs-only)
- `bin/rubocop` → **243 arquivos, 0 ofensas**
- `bin/brakeman --no-pager` → **0 avisos**
- `bin/rails zeitwerk:check` → **All is good**
- `git diff --check docs/` → limpo (apenas aviso CRLF do Windows)
- `git status --short` → ver §8

## 7. Separação: docs de produto × diffs de ferramenta/Graphify
- **Saneamento documental de produto (este trabalho):** os **7 `docs/*.md`** da §1 (+ este relatório).
- **Diffs de ferramenta (NÃO mexidos, reportados à parte):** `.gitignore`, `AGENTS.md` (modificados) e `.claude/`, `.codex/`, `CLAUDE.md` (untracked). São configuração de agente/Graphify, pré-existentes no working tree antes desta rodada — **fora do escopo** e não devem ser commitados junto com o saneamento.

## 8. `git status --short` (no fechamento desta rodada)
```
 M docs/DELIVERY_LOG.md
 M docs/FEATURE_MATRIX.md
 M docs/INDEX.md
 M docs/PB-020_TRIAGEM_CONVERSAS_REQUISITOS.md
 M docs/PRODUCT_BACKLOG.md
 M docs/PROJECT_STATUS.md
 M docs/ROADMAP.md
 M .gitignore            (ferramenta — não toquei)
 M AGENTS.md             (ferramenta — não toquei)
?? .claude/  ?? .codex/  ?? CLAUDE.md   (ferramenta — não toquei)
```
(Após criar este relatório, soma-se `?? docs/relatorios/`.)

## 9. Pendências de coordenação (reportadas, não normalizadas)
- O rótulo **"IMPLEMENTADO E VALIDADO (aguardando aceite do PO)"** usado para **PB-019a/b e PB-020a** convive com PROJECT_STATUS chamando PB-019a/b de **"ENTREGUES/publicadas"** — ambiguidade de **semântica de gate** (validação técnica × aceite operacional) na frente comercial. Fora do escopo desta missão (Triagem/IA); decisão de `omni-coordenar`.
- Drift menor pré-existente: INDEX cita "ADRs 001–022", mas existem ADR-023/024/025 (referenciados nos docs). Fora do escopo; sinalizado para correção futura.

## 10. Recomendação
Commit docs-only sugerido (deixando **de fora** os diffs de ferramenta): `docs: reconcilia governanca com a entrega da Triagem e IA local`. Sem `Co-Authored-By`. Apenas sob autorização explícita do PO.

## 11. Revisão final do diff (auditoria de qualidade) — 25-06-2026
**Parecer: aprovado com 1 ajuste cirúrgico.** Diff dos 7 docs lido como revisor.
- **Ajuste feito (1):** `INDEX.md` — a inserção do M6 havia partido o parêntese do M5 e deixado `M6/M7 ⬜` no fim, marcando **M6 como 🟡 parcial e ⬜ ao mesmo tempo** (contradição residual). Corrigido: parêntese reanexado ao M5 e fecho passou a `· **M6 🟡 parcial** … · M7 ⬜`.
- **Sem outros ajustes:** demais 6 docs coerentes, com evidência (commit/migration/código) e termos de status consistentes; objetividade dentro do estilo já existente dos arquivos.
- **Pendência de coordenação mantida (não normalizada):** convenção "IMPLEMENTADO E VALIDADO (aguardando aceite)" da frente comercial (PB-019/PB-020a) × "ENTREGUE/publicada" — decisão de `omni-coordenar`. Drift menor: INDEX cita "ADRs 001–022" (existem 023/024/025).
- **Validações:** `git diff --check docs/` limpo; `git status --short` só docs de produto + `docs/relatorios/` (novo) + diffs de ferramenta intocados.
