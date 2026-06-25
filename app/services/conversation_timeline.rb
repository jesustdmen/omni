# PB-020 (Triagem) — linha do tempo de uma conversa (read-only).
#
# Deriva os GAPS entre turnos consecutivos a partir de `conversation_turn_refs.ts`
# (o timestamp já está no ÍNDICE no banco — ADR-021), portanto NÃO lê o arquivo
# sessions.jsonl: funciona mesmo quando o LazyLoader devolve :stale. Os gaps são
# apenas EVIDÊNCIA VISUAL nesta fatia — sem classificação (pausa/almoço/...), sem
# persistência, sem promoção a TimeEntry.
class ConversationTimeline
  DEFAULT_GAP_THRESHOLD = 15 * 60 # segundos: só gaps > 15 min aparecem

  # Um gap entre dois turnos (posicionado pelo line_no do turno ANTERIOR).
  Gap = Struct.new(:after_line_no, :seconds, :from_ts, :to_ts, keyword_init: true)

  def self.call(conversation:, threshold_seconds: DEFAULT_GAP_THRESHOLD)
    new(conversation: conversation, threshold_seconds: threshold_seconds).call
  end

  def initialize(conversation:, threshold_seconds: DEFAULT_GAP_THRESHOLD)
    @conversation = conversation
    @threshold = threshold_seconds.to_i
  end

  def call
    @gaps = compute_gaps
    self
  end

  attr_reader :gaps

  # Gaps indexados pelo line_no do turno anterior (a view insere o chip após ele).
  def gaps_by_line
    @gaps_by_line ||= gaps.index_by(&:after_line_no)
  end

  def any_gaps?
    gaps.any?
  end

  def total_gap_seconds
    gaps.sum(&:seconds)
  end

  private

  # Lê só (line_no, ts) do índice, em ordem. Pula turnos sem ts (não quebra) e só
  # considera o intervalo entre dois turnos AMBOS com ts.
  def compute_gaps
    rows = ConversationTurnRef
           .where(conversation_id: @conversation.id)
           .order(:line_no)
           .pluck(:line_no, :ts)

    result = []
    prev_line = nil
    prev_ts = nil

    rows.each do |line_no, ts|
      if prev_ts && ts
        seconds = (ts - prev_ts).to_i
        if seconds > @threshold
          result << Gap.new(after_line_no: prev_line, seconds: seconds, from_ts: prev_ts, to_ts: ts)
        end
      end
      # avança o "anterior" apenas quando há ts (turnos sem ts não ancoram gap)
      if ts
        prev_line = line_no
        prev_ts = ts
      end
    end

    result
  end
end
