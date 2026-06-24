class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include ReturnNavigation # PB-013b — sanitizador central de `return_to` + helpers.

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Autenticação obrigatória em todo o app (telas do Devise são públicas). ADR-003.
  before_action :authenticate_user!

  # Pundit (ADR-004): toda ação resourceful deve autorizar/escopar.
  # Controllers de fundação (dashboard/pages/health) e Devise são dispensados.
  # Lambdas (não `only:`/`except:`) para não referenciar uma ação `index` inexistente
  # em controllers sem index (Devise, contacts) — evita ActionNotFound.
  after_action :verify_authorized, unless: -> { skip_pundit? || action_name == "index" }
  after_action :verify_policy_scoped, if: -> { action_name == "index" }, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def skip_pundit?
    # `search` (PB-013): busca global read-only sobre várias entidades — não é
    # resourceful; a autenticação (Devise) é a barreira. ADR-014 (domínio compartilhado).
    # `settings` (PB-016a): página de Configurações (read-only; ações de escrita têm
    # seus próprios controllers com Pundit, ex.: sync_schedule).
    devise_controller? || params[:controller].to_s.match?(%r{\A(rails/|dashboard\z|pages\z|search\z|settings\z|work_time_reports\z)})
  end

  def user_not_authorized
    flash[:alert] = "Você não tem permissão para essa ação."
    redirect_back fallback_location: root_path
  end
end
