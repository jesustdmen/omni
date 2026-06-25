***

# 📘 Especificação Técnica de Integração: Módulo LLM (Ollama)
**Versão:** 1.0.0
**Data:** [Data de hoje]
**Propósito:** Documentar os requisitos técnicos para que qualquer aplicação possa integrar-se com o serviço Language Model (LLM) fornecido pelo Ollama, garantindo chamadas padronizadas e tratamento de
erros robusto.

---

## 🌐 Sumário Executivo
Este módulo atua como uma camada de abstração entre a lógica de negócio da Aplicação Principal e o serviço externo do LLM (Ollama). O objetivo é realizar um processamento de linguagem natural avançado,
desde tarefas simples (gerar texto) até conversas complexas.

### Requisitos Pré-requisitos
1.  **Serviço:** Ollama deve estar rodando localmente ou em um servidor acessível.
2.  **Protocolo:** Toda comunicação será via **HTTP REST API**.
3.  **Endpoint Base (Assumido):** `http://localhost:11434/api`

---

## 📡 Seção I: Endpoint e Estrutura de Chamada

Todas as chamadas devem ser do tipo `POST`, pois o cliente está enviando dados para que um processamento seja realizado.

### A. Serviço de Geração de Conteúdo (Recomendado)
*   **Endpoint:** `/api/chat` (Ideal para diálogos e prompts contextuais).
*   **Método HTTP:** `POST`
*   **Header Obrigatório:** `Content-Type: application/json`

### B. Exemplo de Payload JSON de Entrada (O "Contrato" de Dados)
A aplicação consumidora deve montar um corpo de requisição seguindo esta estrutura exata:

```json
{
  "model": "nome_do_modelo",
  "messages": [
    { "role": "user", "content": "Seu prompt aqui. Qual o tema?" }
  ],
  "stream": false,         // Deve ser 'false' para processar tudo de uma vez
  "options": {
    "temperature": 0.7,   // Controlo de criatividade (0.0 a 1.0)
    "num_predict": 2048   // Limite máximo de tokens
  }
}
```

#### Detalhamento dos Campos Obrigatórios:

| Campo | Tipo de Dado | Descrição | Validação | Exemplo |
| :--- | :--- | :--- | :--- | :--- |
| `model` | String | Nome do modelo LLM a ser utilizado (Ex: Llama 3). | Deve corresponder a um modelo instalado no Ollama. | `"llama3"` |
| `messages` | Array/Array de Objetos | Histórico de conversação ou prompt inicial. A estrutura é crucial: deve conter objetos com `role` e `content`. | Obrigatório; deve ter pelo menos uma mensagem do
tipo "user". | `[{"role": "user", "content": "Olá!"}]` |
| `stream` | Boolean | Define se a resposta será transmitida em tempo real (streaming). **Para o nosso consumo, deve ser sempre `false`.** | `Boolean` | `false` |

---

## ⚙️ Seção II: Processamento e Resposta Esperada

### A. Estrutura do Payload de Saída
Após a requisição bem-sucedida, o Ollama retornará um JSON que deve ser analisado para extrair *apenas* o conteúdo gerado pelo modelo.

```json
{
  "model": "llama3",
  "created_at": "...",
  "done": true,             // Indica se a geração está completa (true)
  "sem": 0,
  "total_duration": 123456789, // Em nanossegundos
  "usage": { ... },         // Dados de token usado
  "choices": [              // Array com as opções/escolhas geradas.
    {
      "index": 0,
      "message": {           // O objeto que contém o texto final.
        "role": "assistant",
        "content": "Este é o conteúdo de resposta esperado pelo usuário." // <--- ESTE É O DADO CRÍTICO!
      },
      "finish_reason": "stop"
    }
  ]
}
```

### B. Etapa de Processamento Obrigatória (Desserialização)
A aplicação consumidora deve realizar os seguintes passos na ordem:
1. Receber o objeto JSON bruto da API.
2. Acessar o array `choices`.
3. Acessar o primeiro elemento (`[0]`).
4. Extrair o texto do campo `content` dentro de `message`.

**O resultado final esperado pelo resto do sistema é apenas o *texto puro* contido no campo `content`.**

---

## 🛡️ Seção III: Tratamento de Erros e Robustez (MUST READ)
A capacidade de lidar com falhas determina a qualidade da integração. A aplicação deve estar preparada para estes cenários.

| Código HTTP | Tipo de Falha | Causa Provável | Ação Obrigatória do Agente/Aplicação | Mensagem ao Usuário Final |
| :---: | :--- | :--- | :--- | :--- |
| `503` | Serviço Indisponível | Ollama não está rodando, ou a porta foi bloqueada. | Tentar reconectar após um tempo definido (Ex: Retry 3 vezes com intervalo de 5s). Se falhar em todas as tentativas,
avisar o administrador. | "Serviço de Inteligência Artificial indisponível. Verifique se o módulo LLM está ativo." |
| `400` | Bad Request (Requisição Inválida) | O payload enviado está mal formatado ou um campo obrigatório está faltando (ex: `model`). | **Não retentar a chamada.** Logar o erro de validação. Corrigir a
lógica interna que montou o JSON. | "Erro na requisição para IA. Por favor, contate o suporte." |
| `429` | Too Many Requests | O limite de taxa (rate limiting) do servidor foi excedido. | Implementar uma **fila** de processamento e aguardar um período maior antes da próxima tentativa (Backoff). |
"Estamos sob alta demanda. Pedimos que aguarde um momento e tente novamente." |
| Timeout (Não HTTP Code) | Excedeu o tempo limite. | O LLM demorou demais para gerar a resposta. | Implementar lógica de `Retry` com *exponential backoff* (a cada falha, espera-se mais tempo). Se
persistir, tratar como falha 503. | "O processamento da requisição está lento. Pode levar um pouco mais." |

---
***Este documento deve ser anexado ao repositório de código do módulo de Backend/Integração. Ele é o guia oficial para qualquer desenvolvedor que precise consumir o serviço LLM.***