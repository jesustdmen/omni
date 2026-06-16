class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Autenticação obrigatória em todo o app (telas do Devise são públicas). ADR-003.
  before_action :authenticate_user!

  # Pundit (ADR-004): toda ação resourceful deve autorizar/escopar.
  # Controllers de fundação (dashboard/pages/health) e Devise são dispensados.
  after_action :verify_authorized,    unless: :skip_pundit?
  after_action :verify_policy_scoped, if: -> { action_name == "index" }, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def skip_pundit?
    devise_controller? || params[:controller].to_s.match?(%r{\A(rails/|dashboard\z|pages\z)})
  end

  def user_not_authorized
    flash[:alert] = "Você não tem permissão para essa ação."
    redirect_back fallback_location: root_path
  end
end
