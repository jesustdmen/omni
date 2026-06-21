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
  end
end
