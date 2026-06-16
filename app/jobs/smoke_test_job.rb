class SmokeTestJob < ApplicationJob
  queue_as :default

  # Smoke test (ADR-005): prova que o pipeline de Active Job / Solid Queue executa.
  def perform(name = "world")
    message = "smoke-ok: #{name}"
    Rails.logger.info(message)
    message
  end
end
