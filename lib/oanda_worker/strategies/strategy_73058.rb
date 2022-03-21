module Strategies
  class Strategy73058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 5.freeze

    attr_reader :take_profit_base, :stop_loss_base, :use_stop_losses, :channel_box_size_base, :max_trades, :fractal,
                :indicator_pf, :indicator_pf_options, :granularity, :box_size, :reversal_amount, :high_low_close

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @max_trades            = 22.freeze
      @channel_box_size_base = 16.freeze # 55
      @take_profit_base      = 12.freeze # 60
      @use_stop_losses       = false
      @stop_loss_base        = (@channel_box_size_base * (@take_profit_base.to_f / @channel_box_size_base.to_f).ceil).freeze if @use_stop_losses

      @granularity     = ['H1', 'H1'].freeze
      @box_size        = [10, 50].freeze
      @reversal_amount = [3, 1].freeze
      @high_low_close  = ['close', 'high_low'].freeze

      @indicator_pf_options = {
        instrument: instrument,
        granularity: "#{granularity[0]},#{granularity[1]}",
        box_size: "#{box_size[0]},#{box_size[1]}",
        reversal_amount: "#{reversal_amount[0]},#{reversal_amount[1]}",
        high_low_close: "#{high_low_close[0]},#{high_low_close[1]}",
        count: '1,150'
      }

      @indicator_pf = oanda_service_client.indicator(:point_and_figure, @indicator_pf_options).show
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. indicator_pf['data']: #{@indicator_pf['data']}" if @indicator_pf['data'].empty?

      if [1].include?(step)
        candles(smooth: false)
        @fractal = Indicators::Fractal.new(candles: candles, count: 5)
      end

      if [4].include?(step)
        candles(smooth: false, include_incomplete_candles: true, refresh: true)
      end

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy73XX0
  end
end
