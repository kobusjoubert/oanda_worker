module Strategies
  class Strategy70058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 5.freeze

    attr_reader :take_profit_pips, :stop_loss_pips, :channel_box_size_pips, :max_trades, :fractal

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @max_trades            = 20.freeze
      @channel_box_size_pips = 55.freeze
      @take_profit_pips      = 60.freeze
      @stop_loss_pips        = 55.freeze

      if [1].include?(step)
        candles(smooth: false)
        @fractal = Indicators::Fractal.new(candles: candles, count: 5)
      end

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy70XX0
  end
end
