# ADR-022 — Consulta de CNPJ via proxy no Rails (fronteira de saída externa)

## Status
Aceito — 2026-06-21 (PB-006).

## Contexto
O RepoA cadastra clientes com **autopreenchimento por CNPJ**, chamando a **BrasilAPI**
(`https://brasilapi.com.br/api/cnpj/v1/{cnpj}`) **direto do navegador**. O PO decidiu
que o Omni deve ter essa funcionalidade (uso diário), e que a chamada externa deve
ser feita **pelo servidor** (proxy no Rails), não pelo browser nem por serviço de
terceiros embutido. Até aqui o Omni não tinha nenhuma chamada HTTP **de saída**.

## Decisão
Cadastro via busca de CNPJ é servido por um **proxy no Rails**:
1. Endpoint autenticado `GET /clients/cnpj_lookup` (Pundit) recebe **apenas os dígitos** do CNPJ.
2. `Cnpj::Lookup` faz a chamada de saída com **host FIXO allowlisted** (`brasilapi.com.br`),
   **timeout curto** (5s open/read), **falha graciosa** (nunca derruba o request),
   e **não persiste a resposta crua** — devolve só os campos usados pelo form
   (razão social, nome fantasia, telefone, endereço).
3. A URL/host **nunca** vêm de input do usuário; o usuário só fornece o CNPJ (14 dígitos validados).
4. Autopreenchimento no form via Stimulus é **melhoria progressiva** — sem JS, o form funciona manual.

## Alternativas consideradas
- **Browser chama direto (como o RepoA):** simples, sem saída no servidor; mas mistura
  responsabilidade no front e expõe a dependência externa na UI. Preterida pelo PO.
- **Persistir/cachear a resposta crua:** desnecessário no MVP; só os campos mapeados são usados.

## Consequências positivas
- Saída externa **centralizada e controlada** (allowlist + timeout) num único serviço testável.
- Sem segredo de API (BrasilAPI é pública); sem o front falar com terceiros.

## Consequências negativas
- O Omni passa a ter **uma** dependência de rede de saída (degrada graciosamente se indisponível).

## Riscos
- Indisponibilidade/latência da BrasilAPI → mitigado por timeout + mensagem de erro amigável.
- Abuso/rate-limit → escopo é o cadastro manual; sem automação em massa.

## Critérios de aceite
- Busca de CNPJ funciona pelo servidor com host fixo + timeout; sem JS o cadastro segue manual;
  testes não tocam a rede (serviço stubado).

## O que NÃO fazer
- Nunca aceitar host/URL de input do usuário. Não persistir a resposta crua. Não embutir
  chamadas externas em outras telas sem novo ADR. Não logar dados sensíveis da consulta.

## Relação com ADR-011
Mesma filosofia de **fronteira controlada** do ADR-011 (allowlist + timeout + sem input do
usuário), porém para **chamada HTTP de saída** (não execução de processo/pipeline).
