# Sidebar de navegação da Fundação (ADR-001 — ViewComponent).
# Apenas apresentação: agrupa os itens reais existentes (sem rotas novas).
class SidebarComponent < ViewComponent::Base
  Item = Struct.new(:label, :path)
  Group = Struct.new(:title, :items)

  def initialize(current_path:)
    @current_path = current_path.to_s
  end

  def groups
    [
      Group.new("Visão geral", [
        Item.new("Dashboard", "/")
      ]),
      Group.new("Trabalho", [
        Item.new("Clientes", "/clients"),
        Item.new("Projetos", "/projects"),
        Item.new("Tarefas", "/tasks"),
        Item.new("Demandas", "/demands")
      ]),
      Group.new("Sistema", [
        Item.new("Configurações", "/settings")
      ])
    ]
  end

  def active?(item)
    item.path == "/" ? @current_path == "/" : @current_path.start_with?(item.path)
  end
end
