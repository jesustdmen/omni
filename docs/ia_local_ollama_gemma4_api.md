***

# 📘 Especificação Técnica de Integração: Módulo IA Local (Ollama)
**Versão:** 2.0.0
**Propósito:** Documentar os requisitos técnicos para o Omni integrar-se com o serviço de IA local (LLM) fornecido pelo **Ollama**, usando o **endpoint nativo** do Ollama, com chamadas padronizadas e tratamento de erro robusto.

> **Correção 2.0.0 (validada contra o ambiente real):** a versão anterior documentava a
> resposta no formato OpenAI (`choices[0].message.content`). O **endpoint nativo do Ollama
> (`POST /api/chat`)** — o recomendado para o Omni — **não** usa `choices[]`: o texto vem em
> **`message.content`**. O formato `choices[]` pertence ao endpoint de **compatibilidade OpenAI**
> (`/v1/chat/completions`), que **não é** o padrão desta integração. Ver Seção II.

---

## 🌐 Sumário Executivo
Este módulo é a camada de abstração entre a lógica de negócio do Omni e o serviço de IA local (Ollama). O objetivo é obter **sugestões** de processamento de linguagem natural (ex.: objetivo principal de uma conversa, atividades de 2º nível), sempre como **rascunho** sujeito a confirmação humana.

### Pré-requisitos
1. **Serviço:** Ollama rodando localmente (ou em host acessível).
2. **Protocolo:** comunicação via **HTTP REST**.
3. **Endpoint base (host):** `http://localhost:11434`
4. **Modelo identificado no ambiente:** **`gemma4:latest`** (confirmado via `ollama list`).
   - Fixar a tag exata (`gemma4:latest`) por reprodutibilidade; o alias `gemma4` resolve para o mesmo modelo.

### URL configurável por ambiente
A base do Ollama **deve** ser configurável por variável de ambiente:

```text
OMNI_OLLAMA_URL   (default: http://localhost:11434)
```

- **No host (dev nativo):** `http://localhost:11434`.
- **Dentro do container Docker (omni_web):** o Ollama roda no host, então a URL provável é
  `http://host.docker.internal:11434` (definir via `OMNI_OLLAMA_URL`).

---

## 📡 Seção I: Endpoint e Estrutura de Chamada

### A. Endpoint recomendado (nativo do Ollama)
*   **Endpoint:** `POST http://localhost:11434/api/chat`
*   **Método HTTP:** `POST`
*   **Header obrigatório:** `Content-Type: application/json`

> Este é o **endpoint nativo** do Ollama e o **padrão recomendado** para o Omni.
> A montagem de URL completa deve derivar de `OMNI_OLLAMA_URL` + `/api/chat`.

### B. Payload mínimo de entrada (validado)
A aplicação consumidora deve montar o corpo da requisição assim:

```json
{
  "model": "gemma4:latest",
  "messages": [
    { "role": "user", "content": "Seu prompt aqui." }
  ],
  "stream": false,
  "format": "json",
  "options": {
    "temperature": 0.7,
    "num_predict": 2048
  }
}
```

#### Detalhamento dos campos:

| Campo | Tipo | Descrição | Obrigatório |
| :--- | :--- | :--- | :--- |
| `model` | String | Nome/tag do modelo. Deve existir no Ollama (`ollama list`). Ex.: `"gemma4:latest"`. | Sim |
| `messages` | Array de objetos | Histórico/prompt. Cada item tem `role` (`user`/`assistant`/`system`) e `content`. Deve haver ao menos uma mensagem `user`. | Sim |
| `stream` | Boolean | Para o consumo do Omni deve ser **sempre `false`** (resposta única, não streaming). | Sim |
| `format` | String | **Opcional.** `"json"` força o modelo a responder JSON válido — recomendado quando o Omni espera um contrato estruturado (ex.: lista de atividades). | Não |
| `options` | Objeto | **Opcional.** Parâmetros de geração: `temperature` (criatividade), `num_predict` (limite de tokens), etc. | Não |

---

## ⚙️ Seção II: Resposta nativa esperada (`/api/chat`)

### A. Estrutura real do payload de saída
Numa requisição bem-sucedida ao **endpoint nativo**, o Ollama retorna um JSON com o texto em **`message.content`** (confirmado no ambiente real):

```json
{
  "model": "gemma4:latest",
  "created_at": "2026-06-25T14:00:00.000Z",
  "message": {
    "role": "assistant",
    "content": "Este é o conteúdo de resposta gerado pelo modelo."
  },
  "done": true,
  "done_reason": "stop",
  "total_duration": 123456789,
  "load_duration": 98765432,
  "prompt_eval_count": 42,
  "eval_count": 128
}
```

Campos nativos relevantes:

| Campo | Descrição |
| :--- | :--- |
| `message.role` | Papel da mensagem gerada (`"assistant"`). |
| `message.content` | **Texto final gerado — o dado crítico a extrair.** |
| `done` | `true` quando a geração terminou. |
| `done_reason` | Motivo do término (ex.: `"stop"`). |
| `total_duration` | Tempo total (nanossegundos). |
| `load_duration` | Tempo de carga do modelo (nanossegundos) — alto na **primeira** chamada (carga fria). |
| `prompt_eval_count` | Tokens avaliados do prompt. |
| `eval_count` | Tokens gerados na resposta. |

### B. Desserialização correta (nativo)
A aplicação consumidora deve:
1. Receber o JSON bruto de `/api/chat`.
2. Acessar o objeto **`message`**.
3. Extrair o texto de **`message.content`**.
4. (Quando usar `format: "json"`) fazer parse do JSON contido em `message.content` e validar o contrato esperado.

> ⚠️ **NÃO** extrair de `choices[0].message.content`: esse caminho **não existe** na resposta
> nativa `/api/chat`. O resultado esperado pelo resto do sistema é o **texto puro** em
> `message.content` (ou o objeto JSON desserializado dele, quando `format: "json"`).

### C. Sobre `/v1/chat/completions` (compatibilidade OpenAI — NÃO recomendado aqui)
O Ollama também expõe um endpoint de **compatibilidade OpenAI** em `POST /v1/chat/completions`.
**Apenas nesse modo** a resposta vem no envelope `choices[0].message.content`.

- Este **não** é o padrão recomendado para esta integração do Omni.
- A implementação do Omni deve falar com o **endpoint nativo `/api/chat`** e ler `message.content`.
- Caso, no futuro, se opte pelo modo de compatibilidade, **trocar o parsing** para `choices[]`
  conscientemente — os dois formatos não são intercambiáveis.

---

## ⏱️ Seção III: Timeouts recomendados

| Fase | Recomendação | Racional |
| :--- | :--- | :--- |
| Conexão (open) | **2–3 s** | Detecta rápido o servidor fora do ar (Ollama parado/porta bloqueada). |
| Leitura (read) — 1ª chamada | **até 120 s** | A **carga fria** do `gemma4:latest` (~9.6 GB) é cara (`load_duration` alto). |
| Leitura (read) — chamadas seguintes | menor (ex.: 20–30 s) | Com o modelo já residente, a geração é mais rápida. |

Opcional: usar `keep_alive` para manter o modelo carregado entre chamadas e reduzir a latência subsequente.

---

## 🛡️ Seção IV: Tratamento de erro e degradação segura (MUST READ)

A falha da IA **não pode** comprometer o fluxo de produto. Regras obrigatórias:

```text
- A Triagem manual continua funcionando normalmente sem a IA.
- Erro/indisponibilidade do Ollama NÃO bloqueia a tela nem estoura exceção para o usuário.
- Resposta inválida, vazia ou fora do contrato vira "sem sugestão" (degradação graciosa).
```

| Cenário | Causa provável | Ação da aplicação | Mensagem ao usuário |
| :--- | :--- | :--- | :--- |
| Conexão recusada / timeout de conexão | Ollama parado ou porta bloqueada | Tratar como **IA indisponível**; seguir no fluxo manual. Sem retry agressivo dentro da requisição da tela. | "Sugestão por IA indisponível no momento. Continue pela Triagem manual." |
| Timeout de leitura | Carga fria/geração lenta | Encerrar como "sem sugestão" (ou oferecer tentar de novo). Nunca travar a tela. | "A IA demorou para responder. Tente novamente em instantes." |
| Resposta não-JSON / fora do contrato | Modelo devolveu texto inesperado | Descartar como **"sem sugestão"**; logar (redigido) para auditoria. | "Não foi possível interpretar a sugestão da IA." |
| HTTP 400 | Payload malformado (ex.: falta `model`) | **Não retentar**; logar e corrigir a montagem do JSON. | "Erro interno ao consultar a IA." |

---

## 📐 Seção V: Regras de produto (valem para toda a integração)

```text
1. A IA local SUGERE; o humano CONFIRMA.
2. Sugestão da IA vira NO MÁXIMO um rascunho (revisável: confirmar/descartar/reabrir).
3. Nenhuma sugestão cria Task automaticamente.
4. Nenhuma sugestão cria TimeEntry automaticamente.
5. Nenhuma sugestão altera ConversationLink automaticamente.
6. A integração deve ser ISOLADA em adaptador/serviço (a Triagem não acopla ao provedor de IA).
7. Prompt e resposta devem ser AUDITÁVEIS (log redigido, sem vazar PII).
8. Falha da IA NÃO bloqueia Triagem, criação/vínculo de tarefa nem apuração.
9. UI e documentação em PT-BR.
```

Coerência com `docs/PB-020_TRIAGEM_CONVERSAS_REQUISITOS.md` (§2, §9 e bloco "IA LOCAL"):
a IA entra como **camada de sugestão** sobre o fluxo existente; **cliente sugerido por IA**
continua diferente de **cliente confirmado** (a confirmação humana prevalece).

---

***Este documento é o guia oficial de consumo do serviço de IA local (Ollama) pelo Omni. Registro documental — nenhuma implementação (adaptador/serviço/chamada) é feita por este doc.***
