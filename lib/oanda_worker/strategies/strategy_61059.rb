module Strategies
  class Strategy61059 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 1.freeze

    attr_reader :channel_box_size_pips, :channel_box_size_integer

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @channel_box_size_pips    ||= 50
      @channel_box_size_integer = channel_box_size_pips * 10

      if [1, 2, 6, 7].include?(step)
        candles(smooth: false, include_incomplete_candles: true)
      end

      raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps
    end

    include Strategies::Steps::Strategy61XX1
  end
end
