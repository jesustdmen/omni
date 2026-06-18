# Omni — Régua de conformidade visual (UI)

> Referência curta para manter as telas alinhadas ao hi-fi (`_mockup/uploads/Hi-fi *.png` +
> `_mockup/spec-hifi.jsx`/`spec-task-tabs.jsx`). Auditoria de 2026-06-17; patch **F2.UI.1**.
> A F2.UI é **baseline visual provisório**; o redesign final é Fase 5.

## Tokens principais do hi-fi (`spec-hifi.jsx`)
- Fundo `#ffffff`; sidebar `#fafafa`; texto `#0a0a0a`; muted `#71717a`; borda `#e4e4e7`; primário **`#18181b`**; radius **8px**; fonte `system-ui` 14px/1.5.
- **Status:** active=verde · pending=âmbar · in_progress=azul · completed/done=**violeta** · cancelled=vermelho.
- **Tipo:** support=ciano · questions=violeta · implementation=âmbar · development=azul · commercial=rosa.
- **Conversa:** magenta (`#d946ef`).
- Badge = pílula (borda 1px, radius 999px); botão primário preto (+ outline/ghost/sm); busca com ícone à esquerda.

## Conclusão da auditoria
App **aderente à linguagem visual do hi-fi no nível de baseline**. Divergências eram, em quase tudo, **polish (P2/P3)** ou **escopo de Fase 4/5/6**. **Sem bloqueador (P1).** Os itens que faziam parecer "incompleto" foram corrigidos no patch **F2.UI.1**.

## Itens aderentes (✅)
Sidebar (estilo), tabelas, índices/show de clientes/projetos, formulários, botões, estados vazios de índice, conversão de demanda, aba Detalhes.

## Parcialmente aderentes (🟡 — deferidos para ciclo visual pós-F3/M3)
- Sidebar **sem contagens** por item; sem grupo "Conversas"/"Diário" (Fase 4/5/6).
- Topbar **sem "+ Nova"** e sem breadcrumb/data; busca é visual; Ctrl+K (cmdk) = Fase 5.
- Dashboard sem ícones/accent nos cards e sem timeline de atividade (Fase 5).
- Header da tarefa: metadados no `dl` (hi-fi usa linha de metadados + ações apontar/IA).
- Abas da tarefa **sem contagens** e **sem troca dinâmica** (Hotwire na Fase 5).
- Fundo cinza `#f6f7f9` e radius 12px (hi-fi: branco / 8px) — decisão estética deferida.

## Divergências corrigidas nesta etapa (F2.UI.1)
1. **Abas Conversas/Histórico/Demanda**: deixaram de ficar ocultas sem mensagem → agora **placeholders visíveis e intencionais** + flag "em breve" na aba (não parecem mais quebradas).
2. **Badges**: `status_badge` realinhado às cores do hi-fi (status + tipo; novos tons violeta/ciano/rosa).
3. **Duração**: helper `duration_label` (ex.: `45 min`, `1 h 30 min`) na aba Time entries da tarefa e nas telas de time entries (antes: inteiro cru). **Unidade assumida = minutos**, a confirmar na carga real (ver [F3_CONTRACT_DECISIONS.md](F3_CONTRACT_DECISIONS.md)).
4. **Rótulos técnicos**: "Conversas (contador)" → "Conversas".
5. **Dashboard**: removidas as pílulas repetidas "placeholder · Fase 5" (eram 3) → **um único sinal sóbrio** (callout) + textos discretos "em breve".

## Adiado para F4/F5 (precisa seguir specs existentes — não inventar)
Conteúdo real da aba Conversas (sugestões/cards/composer/right-rail), Inbox/triagem, Diário, Workspaces órfãos, Tags, lista/detalhe de Conversa, sync runs visual, command palette (Ctrl+K), handoff, render markdown sanitizado. Specs de referência: `_mockup/spec-task-tabs.jsx`, `spec-convo-render.jsx`, `spec-flows.jsx`, `wf-mailbox.jsx`, `wf-today.jsx`.

## Pendência de validação visual
Não há tela read-only para inspecionar os dados de **F3.1** (conversations/sync_runs). Uma lista read-only mínima pode ser avaliada num próximo ciclo (ou na Fase 5).
