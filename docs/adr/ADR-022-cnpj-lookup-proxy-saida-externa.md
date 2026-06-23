# ADR-022 — Consulta de CNPJ via proxy no Rails (fronteira de saída externa)

## Status
**Revertida** pela decisão original do proxy — ver **Addendum (2026-06-23)**: a consulta de CNPJ voltou a ser feita **no navegador** (como o RepoA). Aceito em 2026-06-21 (PB-006); proxy no servidor removido em 2026-06-23.

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

---

## Addendum (2026-06-23) — consulta volta ao NAVEGADOR (proxy no servidor removido)

A decisão de fazer a consulta **pelo servidor** mostrou-se inviável na prática e foi **revertida**.

**Motivo (comprovado):** a BrasilAPI (plano gratuito) aplica **rate-limit por IP** (~poucas consultas/min). O proxy fazia a chamada **de saída do container**, então **todas** as consultas saem do **mesmo IP** (NAT do Docker), que é compartilhado/“sujo”. Resultado: HTTP **429 mesmo numa única consulta isolada**. Teste lado a lado (2026-06-23): do **host (IP do usuário)** → HTTP **200**; do **container** → HTTP **429**. O "Risco: abuso/rate-limit" deste ADR subestimou esse efeito — o cadastro manual de poucos clientes já bastava para travar.

**Nova decisão:** a consulta volta a ser feita **no navegador** (como o RepoA, que comprovadamente funcionava), usando o **IP do próprio usuário** — sem rate-limit na prática. É uma API **pública, sem chave/segredo**; mover para o cliente **não expõe credencial**. Implementação:

- O **Stimulus** `cnpj_lookup_controller.js` chama `https://brasilapi.com.br/api/cnpj/v1/<14 dígitos>` direto (host **fixo** no cliente — allowlist; só dígitos na URL; máscara removida no front; trata 200/404/429/erro; mapeia razão social/fantasia/telefone/endereço em maiúsculas, como antes).
- **Removidos:** o endpoint `GET /clients/cnpj_lookup`, o `Cnpj::Lookup` (serviço) e seus testes — **sem código morto**.
- **Mantido:** melhoria progressiva (sem JS, cadastro manual); a validação de máscara/dígitos é idêntica à do RepoA (recebe com ou sem máscara; usa só os 14 dígitos).

**Escopo da reversão:** apenas a consulta de CNPJ. **Nenhuma outra** chamada externa muda — sincronização (ADR-011/PB-015/PB-016) e demais rotinas permanecem no servidor. O Omni deixa de ter chamada HTTP de saída (a única que existia era esta).

**O que NÃO fazer (atualizado):** continua valendo host fixo (nunca de input do usuário) e não embutir outras chamadas externas sem novo ADR — agora aplicável ao **cliente** (Stimulus), não ao servidor.
