module Strategies
  module Settings
    module Strategy80106H4
      def settings!
        @risk_pips        = 100.freeze
        @min_pattern_pips = { bat: nil, cypher: nil, gartley: nil }.freeze
        @max_pattern_pips = { bat: nil, cypher: nil, gartley: nil }.freeze
        @deep_gartley     = false.freeze

        # Currently only one type of target is supported at a time.
        # [0.382, :tsl] or [0.382, 0.618] but not both at the same time for the different patterns.
        @targets = {
          bat:     [0.382, 0.618],
          cypher:  [0.382, 0.618],
          gartley: [0.382, 0.618]
        }.freeze

        # Currently only one type of stop is supported at a time.
        # [:extension, 1.13] or [:atr, 7, 1.0] but not both at the same time for the different patterns.
        # When :atr, the second argument need to be the same for all, the third argument can differ.
        @stops = {
          bat:     [:extension, 1.13],
          cypher:  [:extension, 1.13],
          gartley: [:extension, 1.13]
        }.freeze

        @trading_days = {
          bat:     [:mon, :tue, :wed, :thu, :fri, :sat, :sun],
          cypher:  [:mon, :tue, :wed, :thu, :fri, :sat, :sun],
          gartley: [:mon, :tue, :wed, :thu, :fri, :sat, :sun]
        }.freeze

        @trading_times = {
          bat:     [['00:00', '00:00']],
          cypher:  [['00:00', '00:00']],
          gartley: [['00:00', '00:00']]
        }.freeze

        true
      end
    end
  end
end
