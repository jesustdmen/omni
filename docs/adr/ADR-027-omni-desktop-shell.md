# ADR-027 — Omni Desktop Shell (Tauri sobre o stack web local)

## Status
Aceito — 2026-07-13 (decisão de produto/arquitetura do PO; **docs-only nesta etapa — sem
implementação**). Implementação faseada registrada como **PB-024**.

## Contexto (problema)
Hoje o Omni só é utilizável por **comandos manuais**: subir o `omni_db`, rodar `.devstack/up.sh`,
esperar o Puma responder em `http://localhost:3030`, garantir o agente de pipeline no host e,
por fim, abrir o navegador. É um stack Docker (web + jobs + banco) + **agente Python no host**
(`script/pipeline_agent.py`) — reprodutível para desenvolvimento, mas **inadequado para uso
diário como produto**.

A meta declarada pelo PO é **usar o Omni diariamente no Windows sem executar comandos** — abrir
como um aplicativo desktop (na experiência mental de um Spotify/Slack/Linear: janela própria,
ícone, sem cara de navegador). Além do "abrir e usar", há uma **visão de longo prazo** que o PO
pretende construir sobre esse aplicativo: **monitoramento** de serviços/sistema, **agentes locais**
que ele possa executar e supervisionar, **integração com outras aplicações — inclusive dentro do
navegador** — e **relatoria**.

Já existe um registro de produto relacionado — *"PENDÊNCIA FUTURA — Desktop Runtime / Serviços
Autopersistidos"* (25/06/2026, em `PB-020_TRIAGEM_CONVERSAS_REQUISITOS.md`) — levantado quando a IA
local da Triagem depende do índice de turnos (`conversation_turn_refs`, ADR-021) estar atualizado;
hoje a reindexação é **manual** (`bin/rails sync:turn_refs`) e, se o índice fica `:stale`, a Triagem
degrada com segurança. Aquele registro cobre **apenas a camada de runtime/serviços** (serviços
autopersistidos, healthcheck visível, reindexação automática) e **não é ADR nem PB**. **Este ADR o
absorve** como origem dos requisitos dessa camada e acrescenta a decisão que faltava: a **casca
desktop**.

## Decisão
Entregar um **shell desktop** que **embute uma WebView apontada para o stack web local**
(`http://localhost:3030`), **reutilizando 100% do Rails/Hotwire existente sem alterá-lo**. A janela
é a mesma UI do navegador numa moldura nativa (ADR-001/ADR-002 permanecem válidos; nada de SPA,
nada de reescrita).

### Duas camadas (separáveis por design)
- **Camada A — Janela (vitrine):** WebView renderizando `localhost:3030`. É a mesma tela do
  navegador; muda só a moldura (janela própria, ícone, bandeja).
- **Camada B — Supervisor (runtime):** sobe o stack, faz **healthcheck** (`/up` do Rails +
  `/health` do agente), mostra **splash** durante o boot, revela a janela quando verde, e encerra
  o stack ao sair. Também **supervisiona o agente de pipeline** (hoje sem "quem liga").

### Tecnologia da casca: **Tauri (Rust)**
- **Frontend = web (JS/HTML/CSS)** já existente — nenhuma UI é reescrita.
- **Agentes locais = sidecars** em **Python** (o `pipeline_agent.py` e futuros agentes) —
  **não se reescreve agente em Rust**; a casca os empacota, dispara e supervisiona.
- **Rust = apenas a cola nativa fina**: janela, bandeja, splash, autostart, notificações, leitura
  de métricas de sistema e supervisão de processos. A casca poderá ser o ponto de integração com
  navegador/outras aplicações, mas o mecanismo (*native messaging* × HTTP/WS local) permanece
  decisão futura explícita — não é escolhido por este ADR.
- Perfil ideal para um **daemon leve, sempre ligado**, com integrações de sistema — que é
  exatamente a visão de longo prazo (monitoramento, agentes, integração com browser, relatoria).
  Usa o **WebView2** já presente no Windows 11 (binário pequeno); cross-platform no futuro.

### Runtime do MVP: **Docker** (reaproveita o `.devstack`)
O supervisor sobe o stack Docker atual e o consome como está — **zero mudança no Rails no MVP**.
A migração para um **runtime nativo (sem Docker)** fica como **Fase 2 explícita** (exige empacotar
Ruby+Rails+Postgres no Windows; hoje não há toolchain Ruby nativo), com **addendum futuro a ADR-006
(Postgres) e ADR-015 (estratégia de ambiente)**.

`app/.devstack` continua sendo toolchain de desenvolvimento, não um novo frontend nem o repositório
da casca. Na PB-024b ele é **reaproveitado como contrato/transição de orquestração do MVP Docker**;
qualquer adaptação própria de empacotamento nasce no artefato desktop separado. "Zero mudança no
Rails" vale para a casca das PB-024a/PB-024b. A PB-024c é uma fatia posterior e explícita que poderá
alterar o Rails/worker para health operacional e reindexação segura, sob addenda a ADR-011/ADR-021.

### Barra de acabamento: **produto empacotado**
Instalador, **ícone/bandeja (tray)**, **splash** de boot e **auto-update** — recursos maduros do
Tauri. (Um "launcher enxuto" com `Edge --app` + script permanece disponível como PoC/fallback, mas
**não** é o alvo desta decisão.)

### Camada B absorve a pendência de 25/06 (Desktop Runtime)
Ao implementar, a Camada B deve entregar os requisitos daquele registro:
1. Web, banco, Ollama, sync e **indexador de turnos** gerenciados como **serviços autopersistidos**
   (sobem com o app; reiniciam sozinhos).
2. O Omni **detecta** índice de turnos `:stale` (fingerprint divergente do arquivo atual).
3. O usuário **não** depende de rodar `sync:turn_refs` manualmente.
4. A UI/desktop expõe **healthcheck / estado operacional** dos serviços (web, banco, Ollama, sync,
   indexador) — visível ao usuário.
5. A **reindexação** é automática (ao detectar `:stale`) ou acionável com segurança pela UI.

Isso exigirá, na fatia correspondente, **addendum a ADR-021 (indexação de turnos)** e **ADR-011
(fronteira de sync/agente)**.

### Invariantes de segurança e ciclo de vida
- Web e healthchecks do desktop devem ficar expostos apenas no **loopback**; o shell não transforma
  o Omni local em serviço de rede. Devise, CSRF, Pundit e CSP continuam ativos dentro da WebView.
- A WebView só navega internamente no origin do Omni. Links externos abrem no navegador padrão;
  nenhuma navegação arbitrária recebe capacidades nativas.
- Capacidades/plugins do Tauri seguem **allowlist mínima**. É proibido expor shell/command genérico,
  caminho ou argumento vindo da página. Sidecars usam binário/comando/caminho fixos, timeout e
  lifecycle supervisionado; tokens/credenciais nunca entram em URL, UI ou log.
- Fechar a janela pode recolher para a bandeja; **Sair do Omni** encerra os processos que a casca
  possui, em ordem segura. Parar/sair **não remove** banco, volumes, imagens, `output/normalized/`
  ou qualquer dado do usuário. Processos externos que a casca não iniciou não são mortos por nome.
- Colisão de porta, dependência ausente ou healthcheck vermelho gera falha observável; a casca não
  mata processo desconhecido nem recria banco/volume como tentativa automática de recuperação.

### Artefato separado do core
O shell **nasce fora de `app/`** (repositório/pasta própria) e **não se mistura** ao core Rails
versionado. O produto continua sendo o app web; a casca o **consome**, não o contém.

## Alternativas consideradas
- **Electron (JavaScript):** faz tudo que o Tauri faz — bandeja, atalho global, autostart,
  notificação, spawn de Python, servidor HTTP/WS, native messaging — na **linguagem que o time já
  domina (JS)**. **Rejeitado como alvo** pelo peso (empacota o Chromium inteiro, ~150 MB + mais RAM)
  num app **sempre aberto**; a escolha é **reversível** (a maior parte do roadmap vive no Rails +
  sidecars, não na casca), então permanece como plano B se a ergonomia do Rust decepcionar.
- **.NET + WebView2 (C#):** forte no Windows e em integração de SO. **Rejeitado** por introduzir
  C#/.NET, **menos alinhado** ao stack atual (Ruby/JS/Python) do que a casca fina de Rust.
- **`Edge --app` + supervisor em script (Python/PowerShell):** a rota **mais enxuta** (nenhuma
  linguagem nova, sem empacotar navegador). **Rejeitada como alvo** porque a barra escolhida é
  **produto empacotado** (instalador/tray/auto-update), que ela não entrega; **serve de PoC/fallback**.
- **PWA / "Instalar site como app":** custo zero para a janela, mas **não supervisiona o backend**
  (o usuário ainda subiria o stack na mão). **Insuficiente** para a meta "sem comandos".
- **Runtime nativo já no MVP (sem Docker):** removeria a dependência do Docker Desktop, mas é
  **empacotamento pesado** e **não há toolchain Ruby nativo** hoje; toca ADR-006/ADR-015.
  **Adiado** para a Fase 2.
- **Greenfield / reescrever a UI como app nativo:** **rejeitado** — descarta o Rails/Hotwire
  validado sem ganho (a mesma UI roda na WebView).

## Consequências
**Positivas:** "dois cliques" para uso diário; **reutiliza 100%** do Rails/Hotwire (mesma cara
desktop e web); o **agente de pipeline deixa de exigir start manual** (supervisionado pela casca);
base natural para a visão de longo prazo (monitoramento, agentes locais, integração com browser,
relatoria); casca **leve** (WebView2 do SO), adequada a um app sempre aberto; caminho cross-platform
futuro.
**Negativas/limites:** introduz **Rust** como linguagem mantida (superfície **fina** — sidecars em
Python + UI web absorvem quase tudo); **Docker Desktop segue pré-requisito** no MVP; **assinatura de
código / SmartScreen** a resolver para o instalador; um **segundo artefato/repositório** a manter;
durante o boot existe uma janela de **splash** (backend local sobe a cada abertura, ao contrário de
um SaaS sempre no ar).

## Riscos
- **Curva de aprendizado de Rust** — mitigado por uma **spike inicial** (PB-024a) e por manter a
  superfície de Rust mínima (agentes = sidecars Python; telas = web). Plano B reversível: Electron.
- **Docker Desktop como dependência pesada no MVP** — aceito conscientemente; **Fase 2 (runtime
  nativo)** registrada como saída.
- **Assinatura de código / aviso do SmartScreen** no instalador `.exe` — tratar na fatia de
  empacotamento (PB-024d); sem assinatura, o usuário enfrenta atrito de confiança do Windows.
- **Divergência entre o estado real dos serviços e o que a UI mostra** — mitigado pelo
  **healthcheck explícito** da Camada B.
- **Reindexação automática de turnos em momento inoportuno** (custo/concorrência com sync) —
  mitigado tornando-a **segura e/ou acionável**, sob **addendum ao ADR-021/ADR-011**.

## Escopo negativo (o que NÃO fazer)
- **Não alterar o app Rails** para a casca funcionar: a janela consome o web **como está**
  (ADR-001/002/012 intactos; a origem da WebView é `localhost:3030`, a mesma do navegador — a CSP
  restrita do ADR-012 permanece válida; nenhuma ponte JS ampla é autorizada). Essa restrição vale
  para PB-024a/PB-024b; mudanças funcionais da PB-024c exigem contrato/addenda próprios.
- **Não migrar o runtime para nativo no MVP** (Fase 2; addendum ADR-006/ADR-015).
- **Não reescrever agentes em Rust** (sidecars em Python).
- **Não abandonar o navegador** como via de acesso (o web segue acessível em `localhost:3030`).
- **Não versionar/copiar o mockup local** nem misturar a casca dentro de `app/` (CONSTRAINTS).
- **Não usar CDNs** (a casca é local; a CSP do ADR-012 permanece).

## Decisões pendentes (registradas, não decididas aqui)
1. **Runtime nativo sem Docker (Fase 2)** — quando/se, com addendum a ADR-006 e ADR-015.
2. **Mecanismo de integração com o navegador/outras apps** — *native messaging* × servidor local
   HTTP/WebSocket (o Rails já é um servidor local; decidir na fatia de integração).
3. **Política de auto-update e assinatura de código** (certificado, canal de atualização).
4. **Escopo exato de "monitoramento"** (serviços do Omni × métricas de sistema × alertas).
5. **Persistência futura de turnos**, se retomada (hoje: lazy por índice — ADR-021 permanece).

## Fatiamento (registrado como PB-024 no backlog)
- **PB-024a — Spike de validação (Tauri):** protótipo mínimo — janela em `localhost:3030` + 1
  sidecar Python + CPU/RAM na bandeja. **Objetivo:** sentir a ergonomia do Rust e confirmar a
  decisão (ou cair para Electron) **antes** de investir no produto. Sem instalador, sem orquestrar
  o stack e sem executar pipeline/sync: o sidecar da spike é inerte e serve apenas para provar
  start/health/stop e ausência de processo órfão.
- **PB-024b — MVP empacotado:** casca que **sobe o stack Docker**, healthcheck + splash, revela a
  janela, **bandeja**, e **supervisiona o `pipeline_agent.py`**. Instalador básico.
- **PB-024c — Serviços autopersistidos + healthcheck + reindexação automática** (absorve a
  pendência de 25/06): estado operacional visível na UI e reindexação de turnos automática/segura.
  **Addendum a ADR-021 e ADR-011.**
- **PB-024d — Auto-update + assinatura de código** (distribuição confiável).
- **(Fase 2, futura)** — runtime nativo sem Docker (addendum ADR-006/ADR-015).
- **(Visão, futura)** — monitoramento avançado, agentes locais adicionais, integração com o
  navegador/outras apps, relatoria — construídos sobre esta base.

## Critérios de aceite desta decisão
- ADR/PB deixam inequívoco que **Tauri é casca**, Rails/Hotwire permanece a UI e Python permanece a
  linguagem dos agentes; não nasce uma segunda interface de produto.
- PB-024a valida WebView, tray, métricas read-only e lifecycle de um sidecar inerte sem tocar o core.
- PB-024b só avança após a spike confirmar Tauri (ou registrar formalmente a queda para Electron).
- PB-024c não é absorvida silenciosamente pela casca: health/reindexação exigem addenda próprios.
- O artefato desktop nasce fora de `app/`; localização/repositório e publicação têm gate próprio.
