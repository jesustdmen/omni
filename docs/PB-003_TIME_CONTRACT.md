# PB-003 — Controle de tempo operacional · Contrato técnico

> **Tipo:** contrato técnico de implementação (oficial). **Não é implementação.** PB-003 só é executada sob prompt específico e autorização do Product Owner.
> **Data:** 2026-06-19 · **HEAD:** `2bf64be` · **Base:** auditoria `PB-001_PARITY_AUDIT.md` + decisões finais do PO (abaixo).
> **Regra:** este contrato fixa o desenho; mudanças de schema (índice) passam por **gate** antes do commit.

## 1. Contexto

A auditoria PB-001 confirmou que o **controle de tempo** é a maior lacuna funcional entre "CRUD de `time_entries`" e "ferramenta de uso diário". Hoje a duração é **manual** e não há timer. No uso real, o consultor inicia uma atividade, aguarda retorno/validação, é chamado para outra demanda e alterna entre atendimentos — por isso o produto precisa de **timers reais** e **paralelos**.

## 2. Objetivo da PB-003

Permitir registrar tempo com fluidez na tarefa: **iniciar/parar timer com cálculo automático de duração**, **registro retroativo**, **edição/exclusão**, **histórico e totais por dia** na página da tarefa, com **timers paralelos** (configuráveis) e **invariante de 1 timer aberto por tarefa**. Sem timesheet global, faturamento, aprovação, exportação, dashboard avançado ou multiusuário pleno.

## 3. Estado atual observado

- **Schema `time_entries`:** `task_id` (FK), `date` (date, NOT NULL), `start_time` (timestamptz, NOT NULL), `end_time` (timestamptz, null), `duration` (integer, default 0, `CHECK ≥ 0`), `is_running` (boolean, default false, NOT NULL), `description` (text), `conversation_id` (uuid, preparado/sem uso). Índices: task_id, date, start_time, conversation_id.
- **`TimeEntry` model:** `belongs_to :task`; valida `start_time`/`date`/`duration`(int≥0)/`is_running`(bool) + `end_time ≥ start_time`. **Sem cálculo de duração, sem timer, sem `user_id`.**
- **Controller/rotas:** `resources :time_entries` (CRUD HTML completo); `new` aceita `?task_id=`; `conversation_id` fora do `permit`. **Sem start/stop.**
- **`/tasks/:id`:** painel "Time entries" read-only (`order(start_time: :desc)`) + **total geral** (`Task#total_duration = time_entries.sum(:duration)`) + helper `duration_label`.
- **Policies:** `TimeEntryPolicy` = qualquer autenticado (ADR-014, domínio compartilhado).
- **Testes:** `time_entries_test` (10 casos), `time_entry_test` (model), `time_entry_policy_test`; `Task#total_duration` coberto.

## 4. Decisões de produto (PO/PM — finais)

1. **Timer real é P0** — PB-003 implementa start/stop real; retroativo sozinho não basta.
2. **Unidade canônica de `duration` = segundos** (persistência). UI exibe formatado h/min. Antes de implementar, **verificar se `duration_label`/testes assumem segundos ou minutos e ajustar de forma consistente**. **Não** inventar migração de dados históricos sem necessidade real.
3. **Timers paralelos permitidos** em **tarefas diferentes** (alternância entre demandas). "1 timer global" **não** é regra fixa.
4. **Config `allow_parallel_running_timers`** — fonte `ENV ALLOW_PARALLEL_RUNNING_TIMERS`, lida via configuração Rails; **default `true`**; **sem tela de configuração** nesta PB.
5. **Invariante de banco:** **nunca** dois timers abertos na mesma tarefa → **índice único parcial** em `time_entries(task_id)` `WHERE is_running`.
6. **`allow_parallel_running_timers = true`:** permite timers abertos em tarefas diferentes; bloqueia só o **duplicado na mesma tarefa**.
7. **`allow_parallel_running_timers = false`:** bloqueia novo timer se já houver **qualquer** aberto — **validação de aplicação** (sem índice global; o default é paralelo).
8. **Cronômetro ao vivo:** PB-003a **não** precisa de Stimulus tick; basta **"em andamento desde HH:MM"**. Cronômetro em tempo real = melhoria posterior.
9. **Aviso global simples** de timers em andamento (ex.: "3 timers em andamento") com **link para uma lista dos apontamentos em andamento**; **sem dashboard avançado**.
10. **`conversation_id`** — vínculo apontamento↔conversa **fora do escopo** da PB-003.
11. **Sobreposição aceita no MVP:** totais por dia somam os apontamentos registrados; com paralelismo, o **total lançado pode exceder o tempo cronológico decorrido** — contrato e UI deixam claro que o total representa **tempo lançado, não tempo de relógio**.

## 5. Escopo funcional

- Iniciar timer numa tarefa (cria `TimeEntry` running).
- Parar timer em execução (calcula `duration` automaticamente, em segundos).
- Registro retroativo de apontamento.
- Editar/excluir apontamento.
- Histórico de apontamentos na página da tarefa.
- Totalização por dia na página da tarefa (+ total geral já existente).
- Múltiplos timers paralelos (config), com invariante de 1 por tarefa.
- Aviso global simples de timers em andamento + lista.

## 6. Fora de escopo

Timesheet global mensal; faturamento; aprovação de horas; exportação; integração com calendário; dashboard/relatórios; multiusuário pleno e regra "por usuário"; API JSON externa; redesign visual amplo; cronômetro ao vivo (Stimulus tick); vínculo `conversation_id`; tela de configuração; PB-004/PB-005/PB-006.

## 7. Desenho técnico Rails/Hotwire

- **Timer = `TimeEntry` com `is_running=true` e `end_time=nil`.** Iniciar = cria registro running; Parar (`stop!`) = `end_time=now`, `duration=compute` (segundos), `is_running=false`.
- **Ações dedicadas** (start/stop) via rotas, respondendo em **Turbo Streams** para atualizar o painel `#tab-time` sem reload; fallback HTML redirect.
- **Cálculo de duração no model** (não na view). ADR-001 (Hotwire/ViewComponent), ADR-002 (sem React; sem tick ao vivo nesta fatia).
- **Regras de unicidade em duas camadas:** banco (1 por tarefa, sempre) + aplicação (paralelismo configurável).

## 8. Rotas sugeridas

```ruby
resources :time_entries do
  member { patch :stop }                          # parar um timer específico
end
resources :tasks do
  resource :timer, only: [:create], controller: "task_timers"  # POST /tasks/:task_id/timer → inicia
end
# (lista de timers em andamento — aviso global)
get "running_time_entries", to: "time_entries#running", as: :running_time_entries
```
*(Alternativa enxuta: `post :start`/`get :running` como member/collection — decisão menor, sem impacto no contrato.)*

## 9. Model/validações sugeridas (`TimeEntry`)

- `scope :running, -> { where(is_running: true) }`; `def running?`.
- `def self.allow_parallel? ` → lê `Rails.configuration.x.allow_parallel_running_timers` (de `ENV["ALLOW_PARALLEL_RUNNING_TIMERS"]`, default `true`).
- `def stop!(at: Time.current)` → set `end_time`, `duration = (end_time - start_time).to_i` (**segundos**), `is_running=false`, `save!`.
- **Validações novas (só quando `is_running`):**
  - `end_time` deve ser **nil**;
  - **mesma tarefa:** não pode haver outro `running` na mesma `task_id` → "Já existe um timer em andamento nesta tarefa." (espelha o índice; camada banco é a garantia real);
  - **paralelismo:** se `!allow_parallel?` e existir **qualquer** outro `running` → "Há um timer em andamento; pare-o antes (paralelismo desabilitado)."
- `duration` permanece íntegro (paridade RepoA); preenchido só no `stop!`.

## 10. Índice único parcial

- **Migration (gate de schema):**
  `add_index :time_entries, :task_id, unique: true, where: "is_running", name: "idx_time_entries_one_running_per_task"`
- **Semântica:** impede 2º timer aberto **na mesma tarefa** no nível do banco (à prova de corrida/duplo-clique). **Não** restringe timers em tarefas diferentes → compatível com paralelismo.
- A regra global (`allow_parallel=false`) é **só de aplicação** — não há índice global.

## 11. View/UI sugerida (`/tasks/:id`, painel `#tab-time`)

- Botão **"Iniciar timer"** quando a tarefa não tem timer aberto; **"Parar"** quando tem.
- Timer em andamento exibe **"em andamento desde HH:MM"** (sem tick ao vivo).
- Histórico **agrupado por dia** com **subtotal por dia** + total geral; timers abertos sinalizados à parte (sem duração ainda).
- "Novo apontamento (retroativo)" mantém o fluxo atual; reuso de `duration_label` (formatando segundos → h/min).
- **Aviso global simples** (layout): "N timers em andamento" com link para **lista de apontamentos em andamento** (`running_time_entries`). Sem dashboard.
- Nota visível: o total por dia é **tempo lançado** (pode exceder o relógio quando há sobreposição).

## 12. Totais por dia

- Agrupar `time_entries` da tarefa por `date`, somando `duration` dos apontamentos **parados**. Timers abertos não têm `duration` → exibidos à parte como "em andamento".
- **Sobreposição aceita (decisão 11):** com paralelismo, a soma lançada por dia **pode exceder** o tempo cronológico — esperado; a UI explicita "tempo lançado, não tempo de relógio".

## 13. Testes obrigatórios

- **Model:** `stop!` calcula `duration` em segundos; `running?`/scope; bloqueia 2º timer na **mesma** tarefa (índice + validação); com `allow_parallel=true` **permite** timers em tarefas diferentes; com `allow_parallel=false` **bloqueia** novo timer havendo qualquer aberto; `end_time` nil enquanto running.
- **Integração:** iniciar/parar via Turbo; 2 tarefas com timers simultâneos (flag true) OK; flag false bloqueia o 2º; duplicado na mesma tarefa sempre bloqueado; retroativo via create; editar/excluir ok; painel mostra subtotais por dia + total; aviso global + lista de em-andamento; **sobreposição soma normalmente** (assert total lançado).
- **Regressão:** `time_entries_test` (10) e `Task#total_duration` verdes; `conversation_id` não-atribuível; `duration_label` consistente com **segundos** (ajustar se hoje assume minutos).
- **Policy:** start/stop exigem autenticado (ADR-014).
- **Config:** alternar `ALLOW_PARALLEL_RUNNING_TIMERS` muda o comportamento (testar ambos os modos via stub da config).

## 14. Riscos

- **Migration (índice parcial) = gate separado** antes do commit (fatia 003a).
- **Unidade `duration` = segundos:** verificar/ajustar `duration_label` e testes que possam assumir minutos; **sem** migração de dados históricos sem necessidade (decisão 2).
- **Sobreposição (esperada):** total lançado > tempo de relógio — documentar na UI para não ser lido como bug.
- **Corrida/duplo-clique na mesma tarefa:** o **índice parcial** é a garantia real (validação tem janela de corrida).
- **`allow_parallel=false` + concorrência:** "1 global" é só aplicação (sem índice) → janela de corrida teórica nesse modo não-default; aceitável (uso single-operator).
- **Config por ENV:** mudar exige restart (sem tela) — aceitável no MVP.
- **Fuso/`date`:** agrupar por dia com fuso consistente entre `date` e `start_time`.
- **ADR-014/015:** sem `user_id`/regra por usuário; sem runtime-switch/tela de settings.

## 15. Plano de implementação em fatias

- **PB-003a — start/stop + cálculo automático + proteção de timer duplicado por tarefa + config de paralelismo.**
  Migration do **índice único parcial** (→ **gate de schema**); `TimeEntry#stop!`/scope/validações (camadas banco+aplicação); config `allow_parallel_running_timers` (ENV, default true); `TaskTimersController#create` + `TimeEntriesController#stop`; Turbo no painel; "em andamento desde HH:MM"; testes ambos os modos. *Núcleo do valor.*
- **PB-003b — totais por dia no `/tasks/:id`.**
  Agrupamento por `date` + subtotais + total geral + nota de sobreposição. **Sem schema** → código pequeno autorizável.
- **PB-003c — retroativo assistido.**
  Defaults amigáveis no `new` (date=hoje, start_time=agora), validações de coerência; aviso global + lista de em-andamento. **Sem schema.**

## 16. Critérios de aceite

1. Iniciar timer cria `TimeEntry` running (`is_running=true`, `end_time=nil`).
2. Parar calcula `duration` automaticamente **em segundos** e zera `is_running`.
3. **Nunca** dois timers abertos na **mesma** tarefa (índice de banco + validação).
4. `allow_parallel_running_timers=true` (default): **vários timers abertos em tarefas diferentes** permitidos e exibidos.
5. `allow_parallel_running_timers=false`: novo timer **bloqueado** se já houver qualquer aberto, com mensagem clara.
6. Retroativo: registrar apontamento com data/horário/duração manuais.
7. Editar/excluir apontamento funciona.
8. `/tasks/:id` mostra histórico **agrupado por dia** com **subtotal por dia** + total geral; timers abertos sinalizados à parte ("em andamento desde HH:MM").
9. **Aviso global** simples ("N timers em andamento") com link para lista de em-andamento.
10. Totais por dia **somam os apontamentos registrados mesmo com sobreposição**; UI deixa claro que é **tempo lançado, não de relógio**.
11. `conversation_id` **não** implementado; sem `user_id`/regra por usuário (ADR-014); sem runtime-switch/tela de config (ADR-015).
12. Suíte/checks verdes; regressão de time_entries preservada; `duration_label` consistente com segundos.

## 17. Gate antes da implementação

- **PB-003a tem gate de schema** (índice único parcial): implementar → checks → **PARAR e apresentar relatório ANTES do commit** (perguntar "Posso commitar?"). Migration/schema nunca commitada sem autorização.
- **Decisões residuais (menores)** a confirmar no início da 003a: forma exata da rota (`resource :timer` vs `post :start`); confirmação de que `duration_label`/testes assumem minutos hoje (e ajuste para segundos).
- **PB-003b/003c** = código pequeno: implementar → checks → commit local se verde → pedir autorização só para push.
- Push **sempre** sob autorização. Docs (`DELIVERY_LOG`/`FEATURE_MATRIX`/`PROJECT_STATUS`/`PRODUCT_BACKLOG`) atualizados ao fim de cada fatia entregue.
