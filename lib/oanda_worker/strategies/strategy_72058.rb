module Strategies
  class Strategy72058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 3_360.freeze

    attr_reader :max_trades, :channel_increment, :channel_adjustment_seed, :units_increment_factor, :fractal, :funnel_factor,
                :channel_box_size_factor, :take_profit_factor_ranging, :take_profit_factor_trending,
                :granularity, :box_size, :reversal_amount, :high_low_close,
                :pf_indicator, :pf_indicator_options, :trending_market_xo_length, :trending_market_xo_trend_difference

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
      @channel_increment       = 20.freeze
      @channel_adjustment_seed = 40.freeze
      @units_increment_factor  = 1.5.freeze

      @channel_box_size_factor             = 11.freeze
      @take_profit_factor_ranging          = 12.freeze
      @take_profit_factor_trending         = 5.freeze
      @trending_market_xo_length           = 7.freeze # [D 50] boxes
      @trending_market_xo_trend_difference = 14.freeze # [H1 10] boxes

      @granularity     = ['D', 'H1'].freeze
      @box_size        = [50, 10].freeze # 50, 10
      @reversal_amount = [3, 3].freeze
      @high_low_close  = ['close', 'close'].freeze

      @pf_indicator_options = {
        instrument: instrument,
        granularity: "#{granularity[0]},#{granularity[1]}",
        box_size: "#{box_size[0]},#{box_size[1]}",
        reversal_amount: "#{reversal_amount[0]},#{reversal_amount[1]}",
        high_low_close: "#{high_low_close[0]},#{high_low_close[1]}",
        count: '1,1'
      }

      @pf_indicator = oanda_service_client.indicator(:point_and_figure, @pf_indicator_options).show
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. pf_indicator['data']: #{@pf_indicator['data']}" if @pf_indicator['data'].empty?

      if [1, 4].include?(step)
        candles(smooth: false)
      end

      if [1].include?(step)
        @funnel_factor = Indicators::FunnelFactor.new(candles: candles, count: 7, deteriorate_to: 0.3, risk_factor_weight: 0.9).factor # 0..1
        @fractal       = Indicators::Fractal.new(candles: candles, count: 5)
      end

      if [4].include?(step)
        @funnel_factor = initial_funnel_factor
      end

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy72XX0
  end
end
