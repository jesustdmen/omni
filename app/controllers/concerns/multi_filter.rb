# PB-023e — leitura segura de filtros multi-valor a partir dos params.
#
# Os filtros das listas passam a aceitar MÚLTIPLOS valores por critério
# (ex.: `?status[]=todo&status[]=doing`), mantendo compatibilidade com o
# formato escalar antigo (`?status=todo`) — ambos viram Array.
#
# Toda entrada é sanitizada por allowlist (valores desconhecidos são
# descartados em silêncio) antes de chegar às queries. Nunca interpolar
# valor de filtro em SQL — usar sempre `where(coluna: array)`.
module MultiFilter
  extend ActiveSupport::Concern

  # Normaliza params[key] para Array de strings (escalar ou array), sem
  # brancos/duplicados, mantendo só o que estiver na allowlist informada.
  # Retorna Array (possivelmente vazio) — use `where(col: vals) if vals.any?`.
  def filter_list(key, allowlist:)
    allow = allowlist.map(&:to_s)
    raw_filter_values(key).select { |v| allow.include?(v) }
  end

  # Filtros por id de registro (cliente, prestadora…): valida EXISTÊNCIA no
  # banco numa ÚNICA query (sem N+1) e devolve os ids válidos como strings.
  # `model` pode ser uma classe ou um relation já escopado.
  def filter_ids(key, model)
    values = raw_filter_values(key)
    return [] if values.empty?

    model.where(id: values).pluck(:id).map(&:to_s)
  end

  private

  # params[key] → Array de strings limpas (escalar/array; sem brancos/dups).
  def raw_filter_values(key)
    raw = params[key]
    list = raw.is_a?(Array) ? raw : [ raw ]
    list.map { |v| v.to_s.strip }.reject(&:blank?).uniq
  end
end
