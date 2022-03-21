module Strategies
  class Strategy60058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 500.freeze

    attr_reader :take_profit, :stop_loss, :high_low_channel

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      if [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15].include?(step)
        candles(smooth: true, include_incomplete_candles: false)

        @high_low_channel = Overlays::HighLowChannel.new({
          key_base:         key_base,
          round_decimal:    round_decimal,
          pip_size:         pip_size,
          candles:          candles,
          count:            candles_required,
          channel_box_size: 20
        })
      end
    end

    include Strategies::Steps::Strategy60XX0
  end
end
