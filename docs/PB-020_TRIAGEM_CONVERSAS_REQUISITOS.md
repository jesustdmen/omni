# PB-020 — Requisito de Produto: Triagem de Conversas, Atividades e Tempos

> Registro de planejamento/requisito levantado em 2026-06-24. Este documento preserva a memoria da conversa de produto antes de alterar backlog, ADRs ou implementar codigo.

## 1. Visao de produto

O Omni deve transformar conversas tecnicas do VS Code em trabalho operacional rastreavel.

Fluxo desejado:

```text
VS Code
-> Omni importa/normaliza conversas
-> identifica contexto provavel
-> triagem manual/assistida
-> conversa vira tarefa ou se vincula a tarefa
-> Omni sugere atividades e apontamentos
-> usuario valida/ajusta
-> TimeEntries oficiais
-> apuracao
-> validacao
-> precificacao
-> fechamento
-> relatorio
```

A PB-020a atual, baseada em `TimeEntry` existente, continua util, mas nao representa o inicio real do fluxo. A entrada operacional desejada e a conversa importada.

## 2. Decisoes de requisito ja alinhadas

### Uma conversa pode gerar varias atividades

Uma conversa longa pode durar dias e ter um fim unico, mas conter varias atividades de segundo nivel.

Exemplo citado: entrega de um Balanco de Estoque auditado, envolvendo validacao de notas de entrada/saida, criacao de ferramentas auxiliares, consultas auxiliares, validacao de XMLs e ajustes diversos.

Requisito: o Omni deve permitir que uma conversa tenha um objetivo principal e sugira atividades/tarefas de segundo nivel, sem exigir granularidade excessiva.

### IA local pode ajudar, mas nao decidir sozinha

Pode ser avaliado o uso de IA local ja existente, como Gemma, para sugerir:

- objetivo principal da conversa;
- atividades de segundo nivel;
- resumo operacional;
- cliente/projeto provavel;
- descricao de apontamentos.

Regra de produto: IA local deve atuar como assistente de sugestao, nao como decisor final.

### Timestamps sao evidencia, nao relogio absoluto

Conversas longas com pausas nao devem virar automaticamente um apontamento unico nem varios apontamentos definitivos sem revisao.

O metodo de apuracao existente registra os principios:

- o chat sozinho nao representa todo o trabalho executado;
- gaps entre mensagens nao devem ser tratados automaticamente como pausa;
- o calculo deve partir da sequencia de trabalho e descontar apenas ausencias comprovadas;
- evidencias do workspace podem estender blocos de trabalho quando houver coerencia;
- cada gap relevante deve ser destacado para validacao do usuario.

Referencia externa citada:

```text
C:\Sandbox_BI\Brakko\Em Desenvolvimento\_docs\Metodo_Apuracao_Horas_Trabalhadas.md
```

### Cliente/projeto por workspace exige confirmacao

O Omni pode sugerir cliente/projeto usando:

- `conversations.workspace_hash`;
- `workspace_maps.folder`;
- `clients.workspace_paths`.

Mesmo quando houver casamento forte por workspace, o sistema deve pedir confirmacao humana antes de assumir o cliente/projeto.

### Conversas sem cliente entram em fila propria

Conversas sem cliente identificado devem aparecer no Dashboard ou em uma fila de triagem como "sem cliente".

### Relatorio nasce da validacao

O formato de validacao/saida desejado se aproxima da planilha existente:

```text
C:\Sandbox_BI\Brakko\Em Desenvolvimento\_docs\Lista Horas Trabalhadas.xlsx
```

Estrutura observada da aba `Horas`:

- Dia;
- Hora Ini;
- Hora Fim;
- Tempo Real;
- Acumulado;
- Descricao do Assunto.

## 3. Objetos conceituais propostos

### Triagem da Conversa

Estado/decisao humana sobre a conversa importada.

Possiveis estados:

- pendente;
- cliente sugerido;
- sem cliente;
- vinculada a tarefa;
- tarefa criada;
- ignorada / nao trabalho;
- pessoal;
- revisada.

### Atividade Sugerida

Atividade de segundo nivel detectada dentro da conversa.

Pode virar:

- tarefa;
- checklist;
- descricao de apontamento;
- evidencia no relatorio.

### Apontamento Sugerido

Candidato a `TimeEntry`, ainda nao oficial.

Campos conceituais:

- data;
- hora inicial;
- hora fim;
- duracao sugerida;
- assunto/descricao;
- conversa de origem;
- tarefa relacionada;
- gaps pendentes;
- decisao do usuario.

Regra: `TimeEntry` oficial so nasce apos validacao humana ou regra explicitamente aprovada.

## 4. Sequencia de produto recomendada

1. **Triagem operacional de conversas**
   - Dashboard com conversas pendentes.
   - Fila "sem cliente".
   - Sugestao de cliente/projeto por workspace.
   - Confirmacao humana.
   - Criar tarefa ou vincular a tarefa existente.

2. **Atividades sugeridas por conversa**
   - Sugerir objetivo principal e atividades de segundo nivel.
   - Opcional: usar IA local.
   - Nao criar tarefa automaticamente sem revisao.

3. **Apontamentos sugeridos**
   - Aplicar metodo de apuracao sobre timestamps e evidencias.
   - Destacar gaps.
   - Permitir classificar gap como pausa, almoco, trabalho fora do VS Code ou continuidade.
   - Exportar/visualizar em formato semelhante a planilha de horas.

4. **Conversao para TimeEntry oficial**
   - Usuario valida e promove sugestoes para apontamentos oficiais.
   - A partir daqui a PB-020a atual pode apurar horas oficiais.

5. **Apuracao, validacao, precificacao, fechamento e relatorio**
   - PB-020a: apuracao de TimeEntries oficiais.
   - PB-020b: validacao da apuracao.
   - PB-020c: precificacao por contrato.
   - PB-021: fechamento/snapshot.
   - PB-022: relatorio/PDF.

## 5. Armadilhas a evitar

- Criar `TimeEntry` definitivo diretamente a partir de timestamps.
- Tratar uma conversa longa como uma unica tarefa obrigatoria.
- Tratar workspace como verdade absoluta de cliente/projeto.
- Usar IA local para decidir sem explicacao ou confirmacao.
- Misturar apuracao de horas oficiais com triagem de conversas pendentes.

## 6. Proxima decisao recomendada

Antes de mandar implementacao ao executor, desenhar e aprovar o fluxo da **Triagem de Conversas**:

- estados da conversa;
- cards/filas do Dashboard;
- confirmacao de cliente/projeto;
- criacao/vinculo de tarefa;
- relacao entre conversa, atividade sugerida, apontamento sugerido e `TimeEntry`.
