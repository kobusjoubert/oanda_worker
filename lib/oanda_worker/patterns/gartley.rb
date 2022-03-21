module Patterns
  class Gartley < AdvancedPattern
    attr_accessor :deep_gartley

    def initialize(options = {})
      @count            ||= 300.freeze
      @trend            ||= :bullish.freeze
      @b_retracement    ||= options[:deep_gartley] ? [[0.7, 0.786]].freeze : [[0.618, 0.786]].freeze
      @c_retracement    ||= [0.618].freeze
      @d_extension      ||= [1.272].freeze
      @pivot_left_bars  ||= 1.freeze
      @pivot_right_bars ||= 1.freeze
      @rsi_count        ||= 3.freeze
      @rsi_overbought   ||= 65.freeze
      @rsi_oversold     ||= 35.freeze

      # [x, xa, ab, bc, cd]
      case options[:granularity]
      when 'H4'
        @sma_leading_counts ||= [3, 5, 5, 5, 5].freeze
        @sma_lagging_counts ||= [7, 12, 12, 12, 12].freeze
        @min_pattern_pips   ||= 100.freeze
        @max_pattern_pips   ||= 1000.freeze
      when 'H1'
        @sma_leading_counts ||= [3, 5, 5, 5, 5].freeze
        @sma_lagging_counts ||= [7, 12, 12, 12, 12].freeze
        @min_pattern_pips   ||= 60.freeze
        @max_pattern_pips   ||= 600.freeze
      when 'M15'
        @sma_leading_counts ||= [3, 5, 5, 5, 5].freeze
        @sma_lagging_counts ||= [7, 12, 12, 12, 12].freeze
        @min_pattern_pips   ||= 20.freeze
        @max_pattern_pips   ||= 200.freeze
      else
        @sma_leading_counts ||= [3, 5, 5, 5, 5].freeze
        @sma_lagging_counts ||= [7, 12, 12, 12, 12].freeze
        @min_pattern_pips   ||= 10.freeze
        @min_pattern_pips   ||= 100.freeze
      end

      super
    end
  end
end
