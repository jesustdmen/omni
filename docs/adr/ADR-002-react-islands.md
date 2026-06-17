# ADR-002 — Sem React no MVP; ilhas React apenas como possibilidade futura

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
Dois pontos do mockup têm interatividade acima da média: (a) render de conversa (turnos, tool calls colapsáveis, markdown, files_changed); (b) CmdK/busca global (Ctrl+K). O React do Repo A é shadcn genérico, sem lógica de negócio — pouco a preservar.

## Decisão
Sem React no MVP. Render de conversa e CmdK feitos em Stimulus + Turbo. Ilha React permitida apenas como otimização posterior (v1+) e somente para o render de conversa, se Stimulus se mostrar insuficiente — decisão a reavaliar com protótipo na Fase 5.

## Alternativas consideradas
- Adotar ilhas React já no MVP — adiciona build/hidratação sem evidência de necessidade.
- Banir React para sempre — fecha porta sem dados.

## Consequências positivas
- Zero pipeline de JS extra no MVP.

## Consequências negativas
- Se Stimulus não der conta do render de conversa, há retrabalho na v1.

## Riscos
- Render de conversa pode exigir mais que Stimulus — validar com protótipo na Fase 5, não antes.

## Critérios de aceite
- MVP entregue sem dependência React; decisão de ilha (se houver) tomada com protótipo medido.

## O que NÃO fazer
- Não adicionar React "para o caso de precisar".

## Validação futura
- Reavaliar o render de conversa com protótipo na Fase 5.
