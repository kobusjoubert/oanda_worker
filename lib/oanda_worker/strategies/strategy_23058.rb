module Strategies
  class Strategy23058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 52.freeze

    attr_reader :take_profit_increment, :ichimoku_cloud, :fast_exponential_moving_averages, :slow_exponential_moving_averages

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @take_profit_increment = 2.freeze
      fast_ema_count         = 10.freeze
      slow_ema_count         = 21.freeze

      @ichimoku_cloud                   = Overlays::IchimokuCloud.new(candles: candles, tenkan_sen_count: 9, kijun_sen_count: 26, senkou_span_b_count: 52, plotted_ahead: 0)
      @fast_exponential_moving_averages = Overlays::ExponentialMovingAverage.new(candles: candles, count: fast_ema_count).points
      @slow_exponential_moving_averages = Overlays::ExponentialMovingAverage.new(candles: candles, count: slow_ema_count).points

      if [1].include?(step)
        candles(smooth: true, include_incomplete_candles: false)
      end

      raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
    end

    include Strategies::Steps::Strategy23XX0
  end
end
