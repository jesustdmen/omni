<#
.SYNOPSIS
  PB-015 — Orquestração externa da sincronização de conversas do Omni.

.DESCRIPTION
  Executa, em sequência e sem paralelismo:
    1) o PIPELINE EXTERNO (Python, RepoB) que (re)gera output/normalized/;
    2) aguarda a conclusão do pipeline;
    3) solicita/enfileira a IMPORTAÇÃO no Omni (que lê apenas /normalized e roda
       o job em background — o Rails NUNCA executa Python).

  O Rails e o pipeline são responsabilidades separadas (ADR-007/008/011). Este
  script é o "agendador externo" previsto no ADR-011 e deve, no futuro, ser
  registrado como Tarefa do Windows — o que NÃO é feito aqui.

  Não registra senhas nem conteúdo de conversas. Caminhos são parâmetros fixos
  do operador, nunca entrada de usuário final.

.PARAMETER PipelineDir
  Diretório raiz do pipeline externo (RepoB). Default: c:\Sandbox\_omni\_origem\_repob

.PARAMETER PythonExe
  Executável Python (idealmente o do .venv do RepoB). Default: resolve .venv\Scripts\python.exe.

.PARAMETER OmniContainer
  Nome do container Docker do worker/web do Omni para enfileirar a importação.
  Default: omni_web.

.PARAMETER SkipPipeline
  Se presente, NÃO roda o pipeline; apenas enfileira a importação no Omni
  (útil quando o normalized já foi gerado por outro gatilho).

.PARAMETER DryRun
  Mostra o que faria, sem executar pipeline nem importação.

.EXAMPLE
  pwsh -File script\SyncOmniConversations_PB015_v1.ps1
.EXAMPLE
  pwsh -File script\SyncOmniConversations_PB015_v1.ps1 -SkipPipeline
#>
[CmdletBinding()]
param(
  [string]$PipelineDir = 'c:\Sandbox\_omni\_origem\_repob',
  [string]$PythonExe   = '',
  [string]$OmniContainer = 'omni_web',
  [switch]$SkipPipeline,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Exit codes estáveis ----------------------------------------------------
$EXIT_OK              = 0
$EXIT_ALREADY_RUNNING = 2
$EXIT_PIPELINE_FAIL   = 3
$EXIT_IMPORT_FAIL     = 4
$EXIT_BAD_ENV         = 5

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  # Nunca logar segredos/conteúdo; apenas marcos operacionais.
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Write-Host "[$ts][$Level] $Message"
}

# --- Lock: impede execução paralela (mutex global) --------------------------
$mutexName = 'Global\SyncOmniConversations_PB015'
$mutex = [System.Threading.Mutex]::new($false, $mutexName)
$haveLock = $false
try {
  $haveLock = $mutex.WaitOne([TimeSpan]::Zero)
  if (-not $haveLock) {
    Write-Log 'Outra execução já está em andamento — abortando.' 'WARN'
    exit $EXIT_ALREADY_RUNNING
  }

  # --- Validações de ambiente ----------------------------------------------
  if (-not (Test-Path -LiteralPath $PipelineDir)) {
    Write-Log "Diretório do pipeline não encontrado: $PipelineDir" 'ERROR'
    exit $EXIT_BAD_ENV
  }

  if ([string]::IsNullOrWhiteSpace($PythonExe)) {
    $venvPy = Join-Path $PipelineDir '.venv\Scripts\python.exe'
    if (Test-Path -LiteralPath $venvPy) { $PythonExe = $venvPy } else { $PythonExe = 'python' }
  }

  # --- 1) Pipeline externo --------------------------------------------------
  if ($SkipPipeline) {
    Write-Log 'SkipPipeline ativo — não executa o pipeline; apenas enfileira a importação.'
  }
  else {
    $runner = Join-Path $PipelineDir 'pipeline\run_pipeline.py'
    if (-not (Test-Path -LiteralPath $runner)) {
      Write-Log "run_pipeline.py não encontrado em: $runner" 'ERROR'
      exit $EXIT_BAD_ENV
    }
    Write-Log "Executando pipeline externo: $PythonExe $runner"
    if ($DryRun) {
      Write-Log '(dry-run) pipeline não executado.'
    }
    else {
      # 2) aguarda conclusão (chamada síncrona); captura exit code.
      & $PythonExe $runner
      $pipelineExit = $LASTEXITCODE
      if ($pipelineExit -ne 0) {
        Write-Log "Pipeline falhou (exit=$pipelineExit)." 'ERROR'
        exit $EXIT_PIPELINE_FAIL
      }
      Write-Log 'Pipeline concluído com sucesso.'
    }
  }

  # --- 3) Importação no Omni (Rails NUNCA roda Python) ---------------------
  # Enfileira o job lendo apenas /normalized; usa um runner Rails dentro do
  # container. Não recebe paths do usuário.
  $railsCmd = 'execution = SyncExecution.create!(status: "queued", trigger: "scheduled"); ' +
              'SyncConversationsJob.perform_later(execution.id); ' +
              'puts "ENQUEUED #{execution.id}"'
  Write-Log "Enfileirando importação no Omni (container=$OmniContainer)."
  if ($DryRun) {
    Write-Log '(dry-run) importação não enfileirada.'
    exit $EXIT_OK
  }

  & docker exec $OmniContainer bin/rails runner $railsCmd
  $importExit = $LASTEXITCODE
  if ($importExit -ne 0) {
    Write-Log "Falha ao enfileirar a importação (exit=$importExit)." 'ERROR'
    exit $EXIT_IMPORT_FAIL
  }

  Write-Log 'Importação enfileirada. Acompanhe o status em /sync_runs.'
  exit $EXIT_OK
}
finally {
  if ($haveLock) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}
