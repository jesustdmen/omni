# ADR-009 — Importação de turnos: lazy / somente vinculados

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
conversations (metadados) são baratas (~1,1 MB). conversation_turns são caros: 129.500 linhas hoje, sem rotação (dívida P1/P4 do Repo B). Nem toda conversa vira evidência.

## Decisão
O sync em massa importa apenas conversations (metadados). Turnos são materializados sob demanda: (a) ao vincular a conversa (primary/mention) ou (b) ao abrir a conversa pela primeira vez. Conversa não tocada permanece só como metadado; turnos lidos do JSONL quando necessário.
- Não importar todos os turnos no sync inicial.
- Antes da Fase 3, validar tecnicamente o mapeamento thread_id → shards/messages/<sha1>.

## Alternativas consideradas
- Full (importar todos os 129.500) — banco/import lentos, maioria nunca vira evidência.
- Somente vinculados (estrito) — quebra a visualização de conversa não vinculada na triagem.

## Consequências positivas
- Sync rápido; banco enxuto; evidências (vinculadas) sempre persistidas.

## Consequências negativas
- Abrir conversa não materializada exige ler o JSONL on-demand (latência na 1ª abertura).
- Requer guardar ponteiro/shard para localizar turnos da conversa.

## Riscos
- Estratégia de localização dos turnos no arquivo gigante: varrer 240 MB por conversa é caro. Mitigação: ler do shard por hash do thread_id (o pipeline já gera shards/messages/).

## Critérios de aceite
- Sync de N conversas não cria N×turnos; vincular/abrir materializa os turnos daquela conversa; re-materializar é idempotente.

## O que NÃO fazer
- Não fazer insert_all dos 129.500 turnos no sync. Não varrer o arquivo inteiro por conversa.

## Validação futura
- Confirmar `thread_id → shards/messages/<sha1>` antes da Fase 3 (bloqueante).
