# ADR-013 — Política para conversas pessoais

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O mockup prevê "marcar como pessoal" → sai do alerta, vai para área separada, não conta como evidência; sem cifragem por ora. status inclui personal.

## Decisão
Conversa pessoal = conversations.status = 'personal' + user_id dono + Pundit (só o dono vê). Sem cifragem no MVP. Pessoal fica fora de contadores/scorer/triagem e fora da limpeza de retenção.

## Alternativas consideradas
- Cifrar conversas pessoais — complexidade de chaves; adiado.
- Excluir do banco — perde recuperação.

## Consequências positivas
- Simples, alinhado ao mockup; isolamento por policy.

## Consequências negativas
- Dado sensível em claro no banco (aceito no perfil local).

## Riscos
- Se virar multiusuário real (ADR-014), "em claro" exige reavaliar cifragem.

## Critérios de aceite
- Conversa personal não aparece em triagem/contadores e só é acessível pelo dono.

## O que NÃO fazer
- Não enviar conteúdo pessoal a logs/telemetria. Não incluir personal no scorer.

## Validação futura
- Reavaliar cifragem se/quando houver multiusuário real.

## Addendum (F5.1.2, 2026-06-18) — implementação real e decisão b1
> Nota de alinhamento. **Não altera a decisão original acima**; documenta como ela foi implementada até aqui e a decisão de recorte da F5.1.

- **Mecanismo real:** a tabela `conversations` **não tem coluna `status`**; "pessoal" é carregado por uma **coluna boolean `conversations.personal`** (default `false`, `null: false`). Onde o texto da Decisão diz `status = 'personal'`, leia-se **`personal = true`**.
- **`user_id`/ownership:** a coluna `conversations.user_id` existe como **preparação** (ADR-013/014), **sem enforcement de escopo** nesta fase; nenhuma regra de "só o dono vê" foi implementada ainda.
- **Uso atual do flag:** `personal` exclui a conversa dos **contadores** de Task (`Task#recompute_conversation_counters!` conta só `primary` de conversas não-`personal`).
- **Decisão da F5.1 (b1):** ao renderizar turnos read-only em `/conversations/:id`, se `personal = true` o controller **não chama o loader** e a tela exibe apenas um aviso de "conteúdo oculto" — **sem** expor turnos, **sem** ownership/`user_id`, **sem** alterar `ConversationPolicy`. O critério "só o dono vê" do ADR fica para uma fatia futura (b2).
- **Pendência:** quando a visibilidade por dono (b2) for implementada, reconciliar formalmente este ADR (ou criar ADR que o substitua) com `personal` boolean + `user_id` + Pundit.
