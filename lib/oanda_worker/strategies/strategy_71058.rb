module Strategies
  class Strategy71058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 3_360.freeze

    attr_reader :max_trades, :channel_increment, :fractal, :risk_factor, :funnel_factor

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @max_trades = 6.freeze

      # Multiplied by 11 downwards for the order level and by 12 upwards for the take profit level when trading long.
      # Will be adjusted dynamically by multiplying with the funnel factor when calculating the next order level after the first trade.
      # Will stay consistent untill all trades have exited and the strategy restarts.
      @channel_increment = 10

      if [1, 4].include?(step)
        candles(smooth: false)
      end

      if [1].include?(step)
        @funnel_factor = Indicators::FunnelFactor.new(candles: candles, count: 7, deteriate_to: 0.3).factor # 0..1
        @fractal       = Indicators::Fractal.new(candles: candles, count: 5)
        @risk_factor   = @fractal.risk_factor
      end

      if [4].include?(step)
        @funnel_factor = initial_funnel_factor
        @risk_factor   = initial_fractal_risk_factor
      end

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy71XX0
  end
end
