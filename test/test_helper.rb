ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Fase 1: execução serial para determinismo (rate-limit/CSRF dependem de
    # estado de processo do Rack::Attack).
    parallelize(workers: 1)

    fixtures :all

    # Isola o contador do Rack::Attack entre testes.
    setup do
      Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
