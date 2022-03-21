module Strategies
  class Strategy74058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 5.freeze

    attr_reader :max_trades, :channel_box_size_base, :initial_units_channel_base, :channel_box_size_median,
                :take_profit_box_size_base, :auto_take_profit_after, :use_stop_losses, :stop_loss_on_position, :stop_loss_box_size_base,
                :fractal, :indicator_pf, :indicator_pf_options, :granularity, :box_size, :reversal_amount, :high_low_close

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @max_trades                 = 100.freeze
      @initial_units_channel_base = 6.freeze
      @channel_box_size_median    = 6.freeze
      @channel_box_size_base      = 16.freeze # 55
      @take_profit_box_size_base  = 12.freeze # 60
      @auto_take_profit_after     = 4.freeze
      @use_stop_losses            = false
      @stop_loss_on_position      = true
      @stop_loss_box_size_base    = (@channel_box_size_base * (@take_profit_box_size_base.to_f / @channel_box_size_base.to_f).ceil).freeze if @use_stop_losses

      @granularity     = ['H1', 'H1', 'H4', 'D'].freeze
      @box_size        = [10, 50, 20, 100].freeze
      @reversal_amount = [3, 1, 3, 3].freeze
      @high_low_close  = ['close', 'high_low', 'close', 'close'].freeze

      @indicator_pf_options = {
        instrument: instrument,
        granularity: "#{granularity[0]},#{granularity[1]},#{granularity[2]},#{granularity[3]}",
        box_size: "#{box_size[0]},#{box_size[1]},#{box_size[2]},#{box_size[3]}",
        reversal_amount: "#{reversal_amount[0]},#{reversal_amount[1]},#{reversal_amount[2]},#{reversal_amount[3]}",
        high_low_close: "#{high_low_close[0]},#{high_low_close[1]},#{high_low_close[2]},#{high_low_close[3]}",
        count: '1,150,1,1'
      }

      @indicator_pf = oanda_service_client.indicator(:point_and_figure, @indicator_pf_options).show
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. indicator_pf['data']: #{@indicator_pf['data']}" if @indicator_pf['data'].empty?

      if [1].include?(step)
        candles(smooth: true)
        @fractal = Indicators::Fractal.new(candles: candles, count: 5)
      end

      if [4].include?(step)
        candles(smooth: true, include_incomplete_candles: true, refresh: true)
      end

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
      return false if oanda_active_trades.any? && exit_position? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy74XX0
  end
end
