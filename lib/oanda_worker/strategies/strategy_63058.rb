module Strategies
  class Strategy63058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 288.freeze

    attr_reader :order_channel_percentage, :take_profit_percentage, :smoothed_channel_count, :order_size_increment, :max_orders,
                :simple_high_low_channel, :initial_units_channel_base

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @order_channel_percentage   = 0.1.freeze
      @take_profit_percentage     = 0.2.freeze
      @smoothed_channel_count     = 200.freeze
      @order_size_increment       = 1.5.freeze
      @max_orders                 = 10.freeze
      @initial_units_channel_base = 0.02.freeze

      if [1, 2, 3].include?(step)
        candles(smooth: true, include_incomplete_candles: true)

        @simple_high_low_channel = Overlays::SimpleHighLowChannel.new({
          key_base:         key_base,
          round_decimal:    round_decimal,
          pip_size:         pip_size,
          count:            candles_required,
          smoothed_count:   smoothed_channel_count,
          candles:          candles
        })
      end

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy63XX0
  end
end
