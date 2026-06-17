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
