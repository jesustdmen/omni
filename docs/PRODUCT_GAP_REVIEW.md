# Omni — Product Gap Review

> **Tipo:** diagnóstico de produto.  
> **Função:** registrar lacunas entre TaskManager / Viewer / Mockup / Omni antes de nova onda de implementação.  
> **Status:** rascunho oficial inicial para revisão do Product Owner.  
> **Regra:** este documento não autoriza execução por si só. Itens executáveis devem entrar no `PRODUCT_BACKLOG.md`.

---

## 1. Contexto da revisão

Após F7.1, a rota natural parecia continuar para F7.2/readiness de produção. Porém, uma revisão visual das telas do TaskManager e a discussão de produto indicaram que o Omni pode estar tecnicamente avançado, mas ainda não suficientemente validado como ferramenta de uso diário.

A hipótese a validar:

> O Omni tem base técnica e CRUDs importantes, mas ainda pode não cobrir plenamente os fluxos operacionais reais necessários para trabalho diário.

Decisão provisória de rota:

- Pausar F7.2.
- Segurar o push do commit local `497cb49` até revisão do backlog/matriz.
- Reposicionar a próxima onda como Produto Operacional antes de Produção.
- Criar backlog oficial para evitar perda de contexto e execução por inferência.

---

## 2. Fontes de avaliação

| Fonte | Papel na revisão |
|---|---|
| TaskManager (`_origem/_repoa`) | Referência de domínio, telas, API interna React/Express e comportamento operacional |
| Viewer (`_origem/_repob/pipeline/viewer`) | Referência de exploração de conversas, tags, busca, timeline e exportação |
| Mockup (`_mockup`) | Referência visual/funcional e decisões de produto futuras |
| Omni Rails (`app/`) | Produto real em construção |
| `FEATURE_MATRIX.md` | Inventário/status granular atual |
| `ROADMAP.md` | Fases e marcos macro |
| `PROJECT_STATUS.md` | Estado consolidado |
| ADRs | Decisões arquiteturais aceitas |

Restrições permanentes:

- `_origem/` e `_mockup/` são somente leitura.
- Produto e governança vivem em `app/`.
- Pipeline Python permanece externo.
- React não faz parte do MVP, salvo decisão futura explícita.

---

## 3. Critérios de avaliação

Cada recurso observado deve ser classificado por cinco perguntas:

1. **O que o usuário fazia na ferramenta original?**
2. **Isso é necessário para o uso diário do Product Owner?**
3. **O Omni já cobre isso?**
4. **Se cobre, está bom o suficiente ou apenas tecnicamente presente?**
5. **Qual é a decisão: P0, P1, P2, P3 ou descartar?**

Classificação operacional:

| Classe | Significado |
|---|---|
| P0 | Necessário para uso diário |
| P1 | Usabilidade forte / paridade importante |
| P2 | Produção/operação técnica |
| P3 | Evolução futura |
| Descartar | Legado/conveniência que não deve migrar |
| Pendente | Precisa de decisão ou evidência adicional |

---

## 4. Tese de produto atual

O Omni deve ser capaz de centralizar:

- clientes;
- contatos;
- projetos;
- tarefas;
- demandas;
- apontamentos de horas;
- conversas técnicas;
- vínculos entre conversas e trabalho executado.

A ferramenta só deve avançar para produção quando conseguir sustentar um dia real de trabalho sem dependência operacional do TaskManager antigo.

---

## 5. Lacunas por área

### 5.1 Clientes / Contatos

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| Abas Empresas / Contatos | A confirmar no Omni; matriz registra Clientes e Contatos entregues | Facilita manutenção de cadastro | P0/P1 | Auditar |
| Busca por razão social, fantasia ou CNPJ | A confirmar | Essencial para uso diário com muitos clientes | P0 | Auditar |
| Filtro por status | A confirmar | Ajuda a separar ativo/inativo | P1 | Auditar |
| Modal/formulário de empresa com razão social, fantasia, CNPJ, telefone, endereço e status | CRUD entregue, detalhe de campos a confirmar | Cadastro operacional | P0 | Auditar |
| Botão “Buscar” ao lado do CNPJ | Não confirmado | Pode acelerar cadastro, mas depende de fonte externa | P1 | Decidir fornecedor/escopo |
| Contatos por cliente | Matriz indica contato gerido na tela Clientes com filtro por cliente | Operacional importante | P0 | Verificar suficiência |
| Contato principal | Matriz cita `is_primary` | Importante para relacionamento | P0 | Verificar tela/fluxo |

Risco de produto: tratar Cliente/Contato como CRUD entregue pode esconder baixa usabilidade de consulta diária.

---

### 5.2 Projetos

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| Busca por nome/descrição | A confirmar | Necessário para operação | P0/P1 | Auditar |
| Filtro por cliente | A confirmar | Importante para organizar carteira | P0/P1 | Auditar |
| Filtro por status | A confirmar | Importante para operação | P1 | Auditar |
| Campos início/fim/prazo | A confirmar; matriz atual resume como CRUD + FK | Pode ser relevante para gestão | P1 | Auditar schema/telas |
| Orçamento | A confirmar | Pode ser relevante, mas talvez não P0 | P1/P3 | Decidir |
| Duplicar/copiar projeto | Não confirmado | Acelera criação de projetos recorrentes | P1 | Decidir |

Risco de produto: `WD-03 entregue` pode significar apenas CRUD básico, não a experiência operacional visível no TaskManager.

---

### 5.3 Tarefas

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| Busca por título/descrição | A confirmar | P0 para uso diário | P0 | Auditar |
| Filtro por status | A confirmar | P0 | P0 | Auditar |
| Filtro por cliente | A confirmar | P0/P1 | P0/P1 | Auditar |
| Tipo da tarefa | Matriz indica Task possui type/status no domínio | Ajuda organização operacional | P0/P1 | Verificar tela/badges |
| Código da tarefa | ADR-016 adia código legível para v1; telas mostram código | Pode ser importante para referência rápida | P1 | Decidir se volta antes |
| Badges de status/tipo | A confirmar | Usabilidade | P1 | Auditar |
| Ação de visualizar detalhe | `/tasks/:id` existe | Essencial | P0 | Verificar suficiência |
| Detalhe operacional | Parcial; F5.5 melhorou âncoras | Centro do uso diário | P0 | Revisar |

Risco de produto: tarefa pode estar tecnicamente criada, mas ainda não ser boa como central operacional.

---

### 5.4 Controle de tempo

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| Timer com status parado/iniciar | Matriz resume WD-07 como CRUD + soma duration | Muito importante para uso diário | P0 | Auditar/planejar |
| Campo “Descreva o que está fazendo” | A confirmar | Importante para qualidade do histórico | P0 | Auditar |
| Registro retroativo | A confirmar | Essencial para rotina real | P0 | Auditar |
| Histórico de apontamentos | A confirmar | Essencial para revisão de horas | P0 | Auditar |
| Agrupamento por dia | A confirmar | Muito útil para prestação de contas | P0/P1 | Auditar |
| Totalização por dia | A confirmar | Essencial para fechamento de horas | P0 | Auditar |
| Editar/excluir apontamento | A confirmar | Necessário para correções | P0 | Auditar |
| Vínculo com conversa | Campo `conversation_id` existe em time_entries segundo roadmap; uso prático a confirmar | Pode elevar valor do Omni | P1 | Auditar |

Risco de produto: este é provavelmente o maior gap entre “CRUD de time_entries” e “ferramenta diária”.

---

### 5.5 Demandas

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| Listagem em cards | A confirmar | Usabilidade | P1 | Auditar |
| Busca | Matriz cita busca | Importante | P0/P1 | Verificar |
| Filtro por prioridade | Matriz cita filtro por prioridade | Importante | P0/P1 | Verificar |
| Origem: telefone/e-mail/reunião/chat/whatsapp/outros | Matriz cita `origin` | Importante para triagem | P0/P1 | Verificar tela |
| Badge/ícone de origem | A confirmar | Usabilidade | P1 | Auditar |
| Cliente vinculado | Matriz indica dependência WD-01 | Essencial | P0 | Verificar |
| Data/hora | A confirmar | Operacional | P0/P1 | Auditar |
| Converter em tarefa | Entregue como transacional | Essencial | P0 | Verificar usabilidade |
| Editar/excluir demanda | A confirmar | Operacional | P0/P1 | Auditar |

Risco de produto: demanda é entrada de trabalho; se a UX for pobre, o fluxo diário quebra antes de chegar na tarefa.

---

### 5.6 Conversas / Vínculos

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| Lista de conversas com status de vínculo | Entregue F5.4 | Importante | P0 | Validar uso real |
| Abrir conversa com turnos | Entregue F5.1/F5.2/F5.1.5 | Importante | P0 | Validar performance/UX |
| Criar tarefa a partir da conversa | Entregue F5.3 | Muito importante | P0 | Validar uso real |
| Ver vínculo dos dois lados | Entregue F4/F5.5 | Muito importante | P0 | Validar |
| Aba Conversas rica por kind | Roadmap/v1 | Pode ser P1 | P1 | Reavaliar |
| Tags de conversa/workspace | Não iniciado | Pode melhorar recuperação | P1/P3 | Reavaliar |
| Busca full-text em conteúdo | Não iniciado | Pode ser muito útil | P1 | Reavaliar |
| Scorer/auto-link/inbox | Roadmap/v1 | Automação futura | P3 | Manter fora do P0 |

Risco de produto: conversas estão tecnicamente fortes no loop mínimo, mas ainda precisam ser julgadas por recuperação de contexto no uso real.

---

### 5.7 Configurações / Health / Admin

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| Ambiente ativo | ADR-015 descarta runtime-switch | Pode ser informativo, não runtime | P2 | Decidir |
| Health geral | A confirmar; Rails tem `/up`/produção F7.1 | Útil para operação | P2/P1 | Decidir |
| Produção/homologação | Runtime-switch descartado | Não migrar como sessão | Descartar/P2 | Confirmar |
| Gerar homologação | ADR-015 rejeita endpoint HTTP/spawn | Não migrar como endpoint | Descartar | Confirmado pela ADR |
| Status de bases | Pode ser OP/Admin | Útil em produção/local | P2 | Decidir |
| Abas Usuários/Testes | A confirmar | Pode ser admin futuro | P2/P3 | Decidir |

Risco de produto: WD-10 não deve descartar tudo. O que é perigoso é runtime-switch/clone HTTP; health/status pode ainda ser útil.

---

### 5.8 API / Contratos

| Recurso observado | Estado conhecido no Omni | Impacto | Prioridade sugerida | Decisão |
|---|---|---|---|---|
| API React→Express do TaskManager | Omni é Rails monolítico/Hotwire por ADR | Não precisa portar 1:1 | P0 decisão | Inventariar |
| Endpoints CRUD internos | Provavelmente traduzidos para controllers/views Rails | OK se não havia consumidor externo | P0 decisão | Confirmar |
| Ações especiais: convert, duplicate, timer, lookup CNPJ | Precisam existir como rotas/ações Rails se forem produto | Podem ser gaps reais | P0/P1 | Auditar |
| API externa pública | Não confirmada | Se existir, precisa contrato | P0 decisão | Procurar evidência |
| Health/admin endpoints | Parcialmente OP/F7 | Operacional | P2 | Auditar |

Princípio de decisão:

- API interna React antiga → traduzir para controller/view/Turbo Rails.
- Ação de tela → implementar como rota/controller Rails.
- API externa/integrador → documentar/versionar.
- Admin/health → classificar em OP/Admin.
- Runtime-switch/clone HTTP → não migrar conforme ADR-015.

---

## 6. Perguntas abertas para o Product Owner

1. Você precisa usar o Omni para fechar horas/faturamento ou apenas para registrar histórico operacional?
2. O timer em tempo real é obrigatório ou o registro retroativo bem feito já resolve boa parte do uso?
3. O código legível da tarefa é necessário no dia a dia?
4. Duplicar projeto é rotina ou conforto?
5. Buscar CNPJ deve consultar serviço externo ou apenas facilitar preenchimento local?
6. Alguma API precisa ser consumida por outro sistema, automação ou app externo?
7. Health/admin é útil para você como operador local ou só para produção futura?
8. A busca em conteúdo de conversas é P0/P1 ou pode ficar para v1?

---

## 7. Recomendação preliminar

1. Não retomar F7.2 imediatamente.
2. Executar PB-001: auditoria de paridade operacional.
3. Atualizar `FEATURE_MATRIX.md` somente após decisões do Product Owner.
4. Priorizar primeiro controle de tempo, detalhe de tarefa, demandas e clientes/contatos.
5. Tratar API como decisão de contrato, não como cópia da arquitetura antiga.
6. Só retomar F7 após gate de produto operacional.

---

## 8. Saída esperada da próxima auditoria

A próxima auditoria deve produzir:

- lista de lacunas confirmadas;
- lista de features já suficientes;
- decisões de descarte;
- prioridades P0/P1/P2/P3;
- recomendações de recortes pequenos;
- atualização proposta do `PRODUCT_BACKLOG.md`;
- proposta posterior para `FEATURE_MATRIX.md`.
