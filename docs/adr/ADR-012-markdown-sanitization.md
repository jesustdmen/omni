# ADR-012 — Sanitização server-side obrigatória de Markdown/conteúdo de conversa

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
conversation_turns.text é markdown vindo de IA/usuário; tool_input é JSON arbitrário; files_changed são caminhos. Conteúdo é não confiável e será renderizado.

## Decisão
Render server-side com markdown → HTML sanitizado por allowlist (Rails sanitize + lista restrita de tags); tool_input nunca renderizado como HTML cru (sempre em <pre>/escapado); links com rel="noopener nofollow".

## Alternativas consideradas
- Render no cliente — amplia superfície XSS.
- Sem sanitização (confiar na IA) — inaceitável.

## Consequências positivas
- XSS mitigado na origem; comportamento testável.

## Consequências negativas
- Markdown rico (ex.: HTML embutido) é podado.

## Riscos
- Allowlist frouxa reabre XSS — cobrir com teste de payload malicioso.

## Critérios de aceite
- Payload <script>/onerror= em text/tool_input é neutralizado (teste verde).

## O que NÃO fazer
- Nunca usar raw/html_safe em conteúdo de conversa. Nunca renderizar tool_input como HTML.

## Validação futura
- Teste de payload malicioso na Fase 5.
