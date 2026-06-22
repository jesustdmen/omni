require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # PB-003a — permite múltiplos timers abertos em tarefas diferentes (default true).
    # Quando false, bloqueia novo timer se já houver qualquer um aberto. App-wide
    # (ADR-014: domínio compartilhado, sem regra por usuário). Sem tela de config nesta fase.
    config.x.allow_parallel_running_timers =
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("ALLOW_PARALLEL_RUNNING_TIMERS", "true"))

    # PB-015 — diretório FIXO/allowlisted do output normalizado (montado :ro como
    # /normalized no web e no worker). O sync NUNCA aceita path do usuário; só lê
    # daqui. Configurável por ENV apenas para dev/CI, não exposto na UI.
    config.x.normalized_dir = ENV.fetch("OMNI_NORMALIZED_DIR", "/normalized")

    # PB-016a — sincronização COMPLETA pelo Omni (pipeline + importação).
    # O Omni passa a poder executar o pipeline externo (Python/RepoB) ANTES da
    # importação — ainda lendo só /normalized depois (ADR-011 §addendum). Tudo por
    # CONFIGURAÇÃO/ENV; nada vem do usuário (allowlist de executável e script).
    #
    #  - run_pipeline_internally : liga/desliga a execução do pipeline pelo Omni
    #    (false = comportamento PB-015: só importa o /normalized já existente);
    #  - pipeline_python         : executável Python (caminho absoluto ou nome no PATH);
    #  - pipeline_script         : script do pipeline (run_pipeline.py) — caminho absoluto;
    #  - pipeline_dir            : diretório de trabalho do pipeline (chdir);
    #  - pipeline_timeout        : timeout fixo em segundos (mata o processo ao estourar).
    config.x.run_pipeline_internally =
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("OMNI_RUN_PIPELINE_INTERNALLY", "false"))
    # O pipeline roda no HOST (via agente), não no container. O Omni só conhece a
    # URL e o token do agente; o comando do pipeline é fixo NO agente (allowlist).
    # `host.docker.internal` resolve o host a partir do container (Docker Desktop).
    config.x.pipeline_agent_url   = ENV.fetch("OMNI_PIPELINE_AGENT_URL", "http://host.docker.internal:8765")
    config.x.pipeline_agent_token = ENV.fetch("OMNI_PIPELINE_AGENT_TOKEN", "omni-dev-agent")
    config.x.pipeline_timeout     = ENV.fetch("OMNI_PIPELINE_TIMEOUT", "1800").to_i
  end
end
