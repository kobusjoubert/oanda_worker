module Strategies
  class Strategy33059 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 1.freeze

    attr_reader :order_pips, :stop_loss_pips, :channel_box_size_pips

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @order_pips            = 5.freeze
      @stop_loss_pips        = 10.freeze
      @channel_box_size_pips = stop_loss_pips.freeze

      if [1, 2, 3, 7, 8].include?(step)
        candles(smooth: false, include_incomplete_candles: true)
      end
    end

    include Strategies::Steps::Strategy33XX1
  end
end
