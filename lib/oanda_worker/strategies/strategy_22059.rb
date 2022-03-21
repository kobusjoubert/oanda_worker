module Strategies
  class Strategy22059 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    EMA_COUNT        = 48.freeze
    CANDLES_REQUIRED = (EMA_COUNT * 2).freeze

    attr_reader :exhaustion_moving_average_1, :exhaustion_moving_average_2, :exhaustion_moving_average_3,
                :leading_shadow_factor, :lagging_shadow_factor, :take_profit, :take_profit_pips, :take_profit_pip_increments, :stop_loss, :stop_loss_factor

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      if step == 1
        @exhaustion_moving_average_1 = Overlays::ExhaustionMovingAverage.new(candles: candles, count: 6)
        @exhaustion_moving_average_2 = Overlays::ExhaustionMovingAverage.new(candles: candles, count: 24)
        @exhaustion_moving_average_3 = Overlays::ExhaustionMovingAverage.new(candles: candles, count: EMA_COUNT)
        @leading_shadow_factor       = (25.to_f / 100.to_f).freeze
        @lagging_shadow_factor       = (250.to_f / 100.to_f).freeze
        @stop_loss_factor            = (50.to_f / 100.to_f).freeze
        @take_profit_pip_increments  = [25, 75, 125].freeze
        @take_profit_pips            = 0
      end
    end

    include Strategies::Steps::Strategy22XX0
  end
end
