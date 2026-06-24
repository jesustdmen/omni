# ADR-025 — Empresa Prestadora + Contratos (frente comercial)

## Status
Aceito — 2026-06-24 (Etapa 0 / PB-019). **Decisão de modelagem; sem implementação nesta etapa.**

## Contexto
O Omni cobre Cliente atendido, Projetos, Tarefas, Demandas e **Apontamentos** (TimeEntry,
duração em segundos; timezone operacional Brasília — ADR-023). Não existe domínio
**comercial**: não há **Empresa Prestadora** (a empresa pela qual o serviço é prestado),
**Contrato**, valor/hora, vigência, fechamento ou relatório/PDF — confirmado por auditoria
read-only (nenhuma coluna de provider/contract/rate no schema). Esta é a base para
**Cálculo de horas → Fechamentos → Relatórios/PDF**.

Premissas de produto: Cliente = atendido; Empresa Prestadora = por quem presto; uma pessoa
pode prestar por mais de uma prestadora (futuro multiusuário); contratos variam por prestadora;
fechamentos futuros consideram a prestadora.

## Decisão
Criar duas entidades novas e adotar o princípio de **snapshot no fechamento**.

### Empresa Prestadora (`provider_companies`)
Cadastro próprio (distinto de `clients` — **não** renomear Client para Empresa). Campos da
1ª fatia: `name` (razão social, NOT NULL), `trade_name`, `cnpj` (só dígitos, **único entre
prestadoras**, sem cruzar unicidade com `clients`), `email`, `phone`, `address`,
`active` (default true). **Logo e dados fiscais ficam para Relatórios/PDF (PB-022).**

### Contrato (`contracts`)
Pertence a **Empresa Prestadora + Cliente**, com **Projeto opcional**. Campos da 1ª fatia:
`provider_company_id` NOT NULL, `client_id` NOT NULL, `project_id` NULL, `start_date` NOT NULL,
`end_date` NULL, `modality` (**somente `hourly` agora**), `hourly_rate` `decimal(12,4)` NOT NULL
(obrigatório — só há hourly), `status` (**enum fixo**: `draft`/Rascunho, `active`/Ativo,
`suspended`/Suspenso, `ended`/Encerrado), `notes`, `active`. Monetário em **decimal** (nunca float).

### Resolução de contrato (cálculo futuro — PB-020)
Por **data do apontamento**, com **prioridade Projeto > Cliente**:
`TimeEntry → Task → (contrato vigente do Project, se houver) senão (contrato vigente do Client) senão (sem valor)`.

### Apontamento independe de contrato
Registrar tempo **nunca** depende de contrato vigente. Sem contrato, as horas existem para
histórico operacional, mas ficam **sem valor monetário**; a UI sinaliza "sem contrato" (futuro)
sem bloquear a captura de tempo.

### Snapshot no fechamento (protege o histórico)
`TimeEntry` **não** grava contrato nem valor. Enquanto não houver fechamento, o cálculo/preview
usa o contrato vigente pela data. Ao **fechar** um período (PB-021), congela-se um **snapshot**
(prestadora, cliente, contrato, período, horas, valor/hora, total, regras aplicadas) — fonte
oficial do relatório. **Alterar o contrato depois não altera fechamentos já fechados.**

### Sobreposição de contratos
Permitido: contrato **geral** (sem projeto) + contrato **de projeto** vigentes no mesmo período
(o de projeto tem prioridade). Proibido: dois contratos **gerais** sobrepostos para a mesma
prestadora+cliente; dois contratos do **mesmo projeto** sobrepostos. Na PB-019b a regra é
imposta por **validação Rails + testes** (ver Riscos).

### Cardinalidades
Empresa Prestadora 1—N Contratos · Cliente 1—N Contratos · Contrato N—1 Prestadora e N—1 Cliente,
0..1 Projeto · Task/TimeEntry resolvem contrato **em tempo de cálculo** (não armazenam).
**Sem** tabela de junção User↔Prestadora agora (single-admin enxerga todas; N:N fica para
multiusuário futuro).

### UI
**Empresa Prestadora** em **Configurações** (`/settings`). **Contratos** como **item próprio na
sidebar** (volume e relação com cliente/projeto).

## Alternativas consideradas
- **Gravar `contract_id`/valor na TimeEntry:** rejeitado — acopla histórico ao contrato e quebra
  ao editá-lo; o snapshot no fechamento resolve sem poluir o apontamento.
- **`status` de contrato configurável (PB-018):** rejeitado agora — status comercial tem semântica
  fixa; enum simples evita uso indevido.
- **Constraint EXCLUDE temporal no banco já nesta fatia:** adiado (ver Riscos).
- **Modalidades monthly/package agora:** adiado — só `hourly` na 1ª fatia.

## Consequências
**Positivas:** domínio comercial isolado e evolutivo; apontamento permanece simples; histórico
financeiro protegido por snapshot; timezone já correto (ADR-023) favorece cálculo por dia/mês.
**Negativas/limites:** `key`/escopo comercial novo a manter; arredondamento e modalidades
adicionais ficam para fatias seguintes.

## Riscos
- **Sobreposição garantida só na app (Rails) na PB-019b** — sem barreira de banco nesta fatia.
  Risco de concorrência **baixo** no single-admin. **Endurecimento futuro possível** via
  PostgreSQL `EXCLUDE USING gist` + `btree_gist` (extensão **disponível** no PG 16 do projeto;
  exige índices parciais por `project_id IS NULL`/`NOT NULL` e por `status` vigente).
- Até existir fechamento (PB-021), preview reflete o contrato vigente atual (esperado).
- Decimais/arredondamento adiados para PB-020 — não introduzir float antes.

## Fatiamento
PB-019a (Empresa Prestadora CRUD) → PB-019b (Contratos CRUD + validação de sobreposição) →
PB-020 (Cálculo/preview: resolução por data, prioridade projeto>cliente, arredondamento) →
PB-021 (Fechamentos: snapshot) → PB-022 (Relatórios/PDF: logo/fiscal; consome snapshot).

## O que NÃO fazer
Não renomear Client→Empresa; não gravar contrato/valor no apontamento; não bloquear apontar por
falta de contrato; não usar `final` (status configurável) como regra comercial; não criar
User↔Prestadora, mensalidade/pacote, nem `rounding_rule` nesta frente; não iniciar Fechamentos/
Relatórios/Desktop antes da sua fatia.

---

## Addendum — 2026-06-24 (fronteira Apuração × Precificação; sem mudar a decisão)

Esclarecimento de fronteira após auditoria Planejado vs Realizado. **Não altera** a decisão de
Empresa Prestadora/Contratos; apenas posiciona o contrato na camada certa.

- **Apuração de horas antecede o contrato.** Conversas importadas/vinculadas a tarefas são
  **evidência primária** de trabalho; apontamentos manuais (`TimeEntry`) também compõem a apuração.
  A apuração (somar/consolidar horas por tarefa/cliente/projeto/período) **não depende de contrato**.
- **Contrato pertence à camada de PRECIFICAÇÃO** — é **uma forma de precificar** horas apuradas,
  não a origem nem um pré-requisito da apuração. Horas **sem contrato** permanecem **visíveis**
  como "sem contrato"/"sem valor"; nunca escondidas, nunca bloqueadas.
- **Fluxo oficial:** Conversas/Tarefas → **Apuração** (PB-020a) → **Validação** humana (PB-020b) →
  **Precificação** (PB-020c, usa contrato quando existir) → **Fechamento/snapshot** (PB-021) →
  **Relatório/PDF** (PB-022).
- **Fechamento congela o snapshot APÓS a validação** (não a partir da prévia). O relatório/PDF
  nasce do **snapshot do fechamento**, nunca da prévia.
- **Cálculo:** `duration` (segundos) → horas decimais; valor = horas × `hourly_rate` em
  **BigDecimal/decimal** (sem float); arredondamento **apenas visual** nesta fase
  (`rounding_rule` comercial definitiva fica para etapa posterior).
- Reafirmado: `TimeEntry`/`Task`/`Project` **não** recebem `contract_id`/valor; sem snapshot em
  `Contract`.

**Pendências de decisão do PO** (registradas, não decididas aqui): granularidade da validação
(PB-020b); quais status de contrato valorizam na precificação (PB-020c — ex.: Suspenso); tratamento
de horas sem contrato no fechamento (PB-021).
