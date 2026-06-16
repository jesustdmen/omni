# Sidebar de navegação da Fundação (ADR-001 — ViewComponent).
class SidebarComponent < ViewComponent::Base
  Item = Struct.new(:label, :path)

  def initialize(current_path:)
    @current_path = current_path.to_s
  end

  def items
    [
      Item.new("Dashboard", "/"),
      Item.new("Clientes", "/clients"),
      Item.new("Projetos", "/projects"),
      Item.new("Tarefas", "/tasks"),
      Item.new("Demandas", "/demands"),
      Item.new("Configurações", "/settings")
    ]
  end

  def active?(item)
    item.path == "/" ? @current_path == "/" : @current_path.start_with?(item.path)
  end
end
