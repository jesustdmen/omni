# ADR-011 — Estratégia de sync: agendador externo roda pipeline; Rails lê output/normalized/

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O viewer já tem botão que roda o pipeline. Settings preveem "sincronizar agora" + agendamento ("a cada 30 min", "rodar ao abrir"). Executar processo externo do Rails é superfície de risco (injeção/credencial).

## Decisão
Dois gatilhos com responsabilidades separadas:
1. Agendador de Tarefas do Windows executa o pipeline Python (gera output/normalized/).
2. Rails "sincronizar agora" apenas lê output/normalized/ e faz upsert (não dispara o pipeline por padrão).
3. Disparo do pipeline pelo Rails fica fora do MVP ou condicionado a allowlist, timeout e caminho fixo (nunca input do usuário).

## Alternativas consideradas
- Só Rails dispara — acopla Rails à presença de Python no boot; risco de command injection.
- Só agendador — perde o "sync agora" da UI.

## Consequências positivas
- Desacopla execução do pipeline da leitura; Rails não depende de Python para funcionar.

## Consequências negativas
- Dois pontos de configuração (agenda externa + leitura interna).

## Riscos
- Execução externa pelo Rails (se habilitada) = injeção/credencial.

## Critérios de aceite
- "Sync agora" funciona sem disparar pipeline; disparo (se habilitado) usa allowlist e timeout.

## O que NÃO fazer
- Nunca passar caminho/args de binário vindos de input do usuário. Não fazer o Rails depender do pipeline para subir.

## Validação futura
- Configuração segura (allowlist + timeout + path fixo) obrigatória antes de qualquer disparo de pipeline pelo Rails.

## Addendum (2026-06-21) — PB-015 entregue + direção do agendador interno (decisão do PO)
A decisão original permanece válida. Dois esclarecimentos:

1. **PB-015 entregue dentro da decisão atual:** o "sincronizar agora" do Omni (`/sync_runs` → "Atualizar conversas no Omni") **apenas lê** `output/normalized/` (allowlist `config.x.normalized_dir`, padrão `/normalized`, montado `:ro`) e faz upsert idempotente; **não dispara o pipeline**. Processamento em background (SolidQueue, worker `omni_jobs` isolado), com advisory lock contra concorrência e verificação de fingerprint (settle/verify) antes/depois. A orquestração externa (rodar o pipeline + enfileirar a importação) fica no script `app/script/SyncOmniConversations_PB015_v1.ps1` — gatilho externo previsto na decisão (item 1).

2. **Direção futura aprovada pelo PO (uso diário):** o Omni passará a ser a aplicação de uso diário e deverá **orquestrar a importação internamente** — agendador em **Configurações** (intervalos configuráveis), como **processo da própria aplicação** (SolidQueue `recurring.yml` + worker), **sem depender do Agendador de Tarefas do Windows**. Para trazer conversas novas, isso implicará o **Omni disparar o pipeline** — exatamente o caso condicionado no item 3 e em "Validação futura": permitido **somente** sob **allowlist de binário/caminho fixo + timeout + sem input do usuário + sem logar credenciais**. Item de produto: **PB-016 — Agendador interno de importação** (proposto). Esta direção **não** revoga a decisão atual; concretiza o item 3 quando a PB-016 for autorizada/implementada.
