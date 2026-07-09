# ADR-026 — Redesign do core operacional (Rails/Hotwire)

## Status
Aceito — 2026-07-09 (decisão de produto do PO; **docs-only nesta etapa — sem implementação**).

## Contexto (problema)
O Omni cresceu por ondas (MVP interno de conversas, listas operacionais, frente comercial,
Triagem com IA local) e o resultado operacional ficou **burocrático, com telas demais**:

- Os fluxos principais do dia a dia (trabalhar uma tarefa: status, checklist, timer, horas,
  demanda de origem) estão **espalhados** entre lista e detalhe (`/tasks` ↔ `/tasks/:id`),
  exigindo navegação constante.
- A navegação principal expõe **11 itens** em 5 grupos, misturando uso diário (tarefas, horas)
  com operação técnica (Sync) e frentes ainda em maturação (Triagem/Conversas).
- Decisões corretas para o MVP (console read-only de conversas, telas separadas por fase,
  baseline visual provisório da F2.UI) **não devem conduzir o core atual**: eram andaimes de
  validação, não o produto final de uso diário.

Insumo desta decisão: um estudo visual hi-fi local, **não versionado e externo ao repositório**,
usado apenas como referência de direção. **Este ADR consolida integralmente os valores e decisões
resultantes** — o repositório e a documentação oficial **não dependem** desse material local.

## Decisão
Redesenhar o **core operacional** do Omni **sobre o Rails/Hotwire existente em `app/`**
(sem greenfield, sem SPA — ADR-001/ADR-002 permanecem válidos).

### Core imediato (navegação principal)
**Dashboard · Tarefas · Demandas · Clientes · Projetos · Horas · Contratos · Configurações.**

- **Tarefas** serão fundidas em um **workspace lista+detalhe** (lista à esquerda, detalhe à
  direita, na mesma tela) via **Turbo Frames** — em **fatia posterior** à fundação visual.
- **Horas** unifica a lista de apontamentos e os timers em execução em uma única tela
  (cartões de timers no topo + tabela de apontamentos).
- **Conversas/Triagem permanecem funcionais** (rotas e features intactas), mas **saem da
  navegação principal nesta etapa**; o redesign desse domínio é etapa 2 (decisão pendente).
- **Sync** vira operação **admin**: acesso via Configurações → Sincronização (a tela
  `/sync_runs` permanece como console operacional/diagnóstico).
- **Apuração de horas** fica **adiada** (item de menu visível porém inerte até seu redesign).

### Primeira fatia (PB-023a — fundação visual, sem migration)
1. **Tokens visuais oficiais** como CSS custom properties (tabela abaixo é a fonte).
2. **Fontes servidas localmente** pelo asset pipeline (licenças abertas; **sem CDN** — a CSP
   restrita do ADR-012 permanece).
3. **Ícones oficiais via dependência adequada** (biblioteca Remix Icon, estilo *line*, licença
   Apache 2.0), **sem copiar assets de referências locais**; substitui os SVGs autorais
   `ACTION_ICONS` gradualmente.
4. **Shell novo**: sidebar (largura fixa, grupos do core acima) + topbar (título/subtítulo da
   tela, chip global de timers com soma de tempo, botão primário contextual).
5. **Dashboard** como primeira tela de prova dos tokens.
6. **Sem migration, sem mudança de schema/rotas/comportamento**; suíte verde em cada passo.

### Tokens visuais oficiais (fonte de verdade)
> Valores definitivos — não arredondar para grids/defaults de biblioteca.

**Cores base**

| Token | Hex | Uso |
|---|---|---|
| Accent / marca (petróleo) | `#0e6e6b` | Botões primários, links, realces, nav ativa |
| Accent escuro | `#0e5c59` | Texto de timer, títulos sobre petróleo claro |
| Accent bg suave | `#e2efee` | Fundo de badges/nav ativa, chips de timer |
| Accent borda suave | `#d3e7e5` | Borda de cartões de timer |
| Texto principal | `#1a2b29` | Corpo |
| Texto médio | `#33413d` / `#4a5a56` / `#55635f` | Rótulos, descrições |
| Texto suave | `#8a958f` / `#9aa39d` | Metadados, placeholders |
| Texto desabilitado | `#b0b7ae` / `#c3c9c1` | Vazios, "—" |
| Fundo app | `#eceae4` | Fundo fora dos painéis |
| Fundo conteúdo | `#ffffff` | Painel principal |
| Fundo conteúdo alt | `#faf9f6` | Áreas de listagem scrolláveis |
| Fundo sidebar / trilha | `#fbfaf7` / `#fcfbf9` | Sidebar, coluna de lista, cabeçalho de tabela |
| Borda padrão | `#e6e3dc` | Cartões, inputs, sidebar |
| Bordas sutis | `#edeae3` / `#f2f0ea` / `#f5f3ee` | Divisores internos, linhas de tabela |

**Cores de status** (bolinha + rótulo): Aberta `#64748b` · Em andamento `#2563eb` ·
Em revisão `#b45309` · Concluída `#178a50` · Cancelada `#dc2626`. Projeto reusa
(Planejamento `#64748b`, Concluído `#178a50`, Suspenso `#b45309`). Contrato: Rascunho
`#94a3b8`, Ativo `#178a50`, Suspenso `#b45309`, Encerrado `#64748b`. Prioridade de demanda:
Alta `#dc2626`, Média `#b45309`, Baixa `#64748b`.
*(Convivência com ADR-024: os status configuráveis continuam mandando na cor dos badges de
Tarefas/Projetos; os valores acima são os defaults/seed sugeridos e as cores dos domínios de
status fixos.)*

**Cor de destaque configurável** (Configurações → Aparência; preferência **por dispositivo**,
implementada como CSS custom property `--accent`): Petróleo `#0e6e6b` (padrão) · Índigo
`#4f46e5` · Verde `#178a50` · Âmbar `#b45309` · Violeta `#7c5cd6` · Ardósia `#475569`.

**Tipografia** (servida localmente): **Space Grotesk** (títulos/números de destaque, 600/700) ·
**Hanken Grotesk** (corpo/UI, 400–800) · **IBM Plex Mono** (códigos `TSK-000042`, CNPJ,
horários, durações; 400–600). Escala (px): H2 de tela 26/600; título de seção 19/600; título de
card 14.5–15/600; corpo 13.5–14 (lh 1.6); metadados 11.5–12.5; rótulo de tabela uppercase
11/700/ls .05em; timer mono 26/500; stat 32/600. `font-variant-numeric: tabular-nums` em todos
os números alinhados.

**Medidas, raio e sombra**: sidebar **238px** · topbar **58px** · coluna de lista de tarefas
**340px** · sub-nav de Configurações **216px** · larguras máx.: listas 1180px, detalhe de tarefa
920px, Configurações 820px · padding de conteúdo ~24–26px vertical / 30–34px horizontal ·
raios: inputs/botões 8–10px, cards 12–16px, pills 99px · sombra de card em hover
`0 6px 18px -12px rgba(20,42,38,.3)` · item de lista selecionado
`inset 3px 0 0 #0e6e6b, 0 4px 14px -8px rgba(20,42,38,.25)` + borda `#e2efee` ·
animação `omniPulse` (opacidade+escala, 1.4–1.6s) nas bolinhas de timer ativo · layout por
`gap` de grid/flex (nunca margens soltas entre irmãos).

## Alternativas consideradas
- **Greenfield (novo app/SPA React):** rejeitado — descarta backend validado (suíte extensa,
  auth endurecida, sync, PII), reabre ADR-001/002 sem ganho visual (o design é alcançável com
  Hotwire) e bifurca o produto.
- **Re-skin sem mudança estrutural:** rejeitado como fim — resolve estética mas não o problema
  central (fluxo espalhado); a fusão do workspace de Tarefas é parte da decisão.
- **Manter Conversas/Triagem na navegação principal:** rejeitado nesta etapa — a frente ainda
  está em maturação (aceites pendentes) e polui o core diário; permanece acessível por rota e
  volta ao menu na etapa 2.

## Consequências
**Positivas:** core diário enxuto (8 telas); tarefa vira centro operacional real (workspace);
identidade visual própria e consolidada em doc oficial; tema/accent por dispositivo; nenhuma
perda funcional (tudo continua roteável).
**Negativas/limites:** duas "peles" convivem durante a transição (telas do core novas ×
Conversas/Triagem no baseline antigo); esforço de re-skin distribuído em fatias; fontes/ícones
vendorizados aumentam o peso de assets (local, aceitável).

## Riscos
- **Regressão visual/funcional durante o re-skin** — mitigado por fatias pequenas com suíte
  verde e aceite do PO por fatia.
- **Acesso a Conversas/Triagem após saírem do menu** — mitigar mantendo rotas e oferecendo
  acesso secundário (ex.: via Configurações) até a etapa 2.
- **Drift entre tokens e implementação** — mitigado por CSS custom properties centralizadas e
  pela régua de conformidade (UI_COMPLIANCE_AUDIT) apontando para este ADR.

## Escopo negativo (o que NÃO fazer)
- **Não reimplementar/alterar o domínio de conversas** (Triagem, validação de tempo, vínculos,
  IA local) nesta frente.
- **Não mexer em sync/pipeline** (ADR-011 e addenda permanecem).
- **Não mudar banco/schema** na primeira fatia; o vínculo tarefa↔contrato (migration aditiva
  opcional) só entra após decisão do PO.
- **Não implementar herança de valor/hora contrato→apontamentos/apuração** (decisão pendente;
  qualquer vínculo tarefa↔contrato nasce informativo).
- **Não versionar/copiar o mockup local** (assets, HTML, JS ou ícones); referências visuais
  externas seguem fora do Git (CONSTRAINTS).
- **Não usar CDNs** para fontes/ícones (CSP restrita — ADR-012).

## Decisões pendentes (registradas, não decididas aqui)
1. **Herança de valor/hora contrato→apontamentos** (e criação do vínculo tarefa↔contrato com
   migration aditiva) — decisão do PO; interage com PB-020c/PB-021 (ADR-025).
2. **Etapa 2 — redesign de Conversas/Triagem** (retorno à navegação principal, tela e fluxo).
3. **Persistência futura de turnos**, se algum dia retomada (hoje: lazy por índice — ADR-021
   permanece).

## Fatiamento (registrado como PB-023 no backlog)
PB-023a (fundação visual + shell + dashboard; sem migration) → PB-023b (workspace fundido de
Tarefas via Turbo Frames) → PB-023c (re-skin das demais telas do core: Demandas, Clientes,
Projetos, Horas unificada, Contratos) → PB-023d (Configurações reorganizada + Aparência:
tema/accent por dispositivo). Apuração e Conversas/Triagem têm redesign em etapas próprias
futuras.
