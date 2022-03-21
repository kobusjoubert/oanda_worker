module Strategies
  class Strategy34058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 1.freeze

    attr_reader :indicator_pf, :indicator_pf_options, :granularity, :box_size, :reversal_amount, :high_low_close,
                :channel_box_size_base, :channel_box_size_median, :initial_units_channel_base,
                :take_profit_box_size_base, :stop_loss_box_size_base

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @initial_units_channel_base = 6.freeze
      @channel_box_size_median    = 6.freeze
      @channel_box_size_base      = 2.freeze
      @take_profit_box_size_base  = 3.freeze
      @stop_loss_box_size_base    = 50.freeze

      @granularity     = ['H1'].freeze
      @box_size        = [50].freeze
      @reversal_amount = [1].freeze
      @high_low_close  = ['high_low'].freeze

      @indicator_pf_options = {
        instrument: instrument,
        granularity: "#{granularity[0]}",
        box_size: "#{box_size[0]}",
        reversal_amount: "#{reversal_amount[0]}",
        high_low_close: "#{high_low_close[0]}",
        count: '350'
      }

      @indicator_pf = oanda_service_client.indicator(:point_and_figure, @indicator_pf_options).show
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. indicator_pf['data']: #{@indicator_pf['data']}" if @indicator_pf['data'].empty?

      if [1, 4, 5, 6, 7].include?(step)
        candles(smooth: true, include_incomplete_candles: true, price: 'MAB')
      end

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy34XX0
  end
end
