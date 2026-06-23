# ADR-023 — Timezone operacional = Brasília; persistência no banco = UTC

## Status
Aceito — 2026-06-23 (correção de timezone; aceite visual do PO).

## Contexto
A aplicação rodava sem `config.time_zone` (default **UTC**): `Time.zone="UTC"`,
`Time.current` em UTC. Como o operador trabalha em **Brasília (UTC−3)**, isso
causava: (1) `datetime-local` de apontamento retroativo interpretado como UTC
(ex.: "09:00" virava 06:00 BR); (2) exibição de horários 3h adiantada; (3) o
`date` de `TimeEntry` — derivado de `start_time.to_date` — caía no **dia em UTC**,
divergindo do dia operacional perto da meia-noite; (4) o agrupamento do histórico
por dia usava esse `date` (dia errado). O banco já armazenava instantes em UTC.

Esta política impacta diretamente o **cálculo de horas**, o **agrupamento por dia**
e, no futuro, **Fechamentos e Relatórios** — por isso vira decisão registrada.

## Decisão
1. **Timezone operacional = Brasília**: `config.time_zone = "Brasilia"` (alias Rails
   → `America/Sao_Paulo`). UI, lançamentos, agrupamento por dia e derivações de data
   usam Brasília.
2. **Persistência em UTC**: `config.active_record.default_timezone = :utc`. O instante
   é gravado/lido em UTC; a conversão para Brasília ocorre na borda (exibição/derivação).
3. **Parse idiomático**: `datetime-local` ("YYYY-MM-DDTHH:MM") é interpretado no
   `Time.zone` (Brasília) pelo próprio Rails — sem parser custom.
4. **`date` de `TimeEntry` deriva do dia operacional**: `start_time.in_time_zone.to_date`
   (em `derive_date_and_duration` e `start_for`), nunca `to_date` em UTC.
5. **Exibição via helpers centrais** (`local_datetime`/`local_time`/`local_date` em
   `ApplicationHelper`), que convertem para Brasília — em vez de `strftime` direto.
   Escopo desta correção: superfícies de **TimeEntry** (index/running/show/_form e a
   seção de timer/histórico em `tasks/show`). Padronização PT-BR ampla = trabalho futuro.
6. **`duration`** continua derivada por diferença de instantes (segundos) — independe
   de timezone; `stop!` segue usando `Time.current`.

## Alternativas consideradas
- **Manter UTC e converter só na view:** não resolve a derivação de `date`/agrupamento
  nem o parse do retroativo; espalha conversões.
- **Persistir em horário local:** quebra portabilidade/ordenções e foge do idiomático
  Rails; rejeitada (banco permanece UTC).

## Consequências positivas
- Horários lançados/exibidos coerentes com Brasília; `date`/agrupamento corretos
  inclusive na virada do dia; base sólida para horas/Fechamentos/Relatórios.
- Banco permanece em UTC (portável, sem ambiguidade de DST na persistência).

## Consequências negativas / Riscos
- `America/Sao_Paulo` tem histórico de **DST** (horário de verão). Hoje o Brasil não
  observa DST; cálculos sobre datas históricas com DST dependem do tzinfo (correto via
  Rails/tzinfo), mas vale atenção em relatórios que cruzem períodos antigos.
- Telas fora de TimeEntry ainda usam `strftime` direto (exibem UTC) até a padronização
  PT-BR — inventário para PB futura.

## Critérios de aceite
- `Time.zone.name = "Brasilia"`; banco em UTC; `09:00` retroativo salva 12:00 UTC e
  exibe 09:00; fronteira 00:30/22:00 BR deriva `date` no dia de Brasília; histórico
  agrupa pelo dia BR; `duration`/`stop!` inalterados. (Coberto por
  `test/integration/timezone_brasilia_test.rb`.)

## O que NÃO fazer
- Não persistir em horário local (banco é UTC). Não usar `Time.now`/`Date.today`/
  `.to_date` cru em horários operacionais — usar `Time.current`/`in_time_zone`.
- Não fazer backfill de dados existentes sem autorização (esta correção **não** alterou
  registros; os instantes UTC seguem corretos e passam a ser exibidos em Brasília).
