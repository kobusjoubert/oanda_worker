module Strategies
  class Strategy49826 < Strategy
    INSTRUMENT       = INSTRUMENTS['US30_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['US30_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 250.freeze
    RSI_COUNT        = 14.freeze

    attr_reader :risk_factor, :exit_factor, :box_size, :granularity, :reversal_amount, :high_low_close, :relative_strength_index

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @risk_factor             = 500.freeze
      @exit_factor             = 18.freeze
      @granularity             = ['H1', 'D'].freeze
      @box_size                = [10, 10].freeze
      @reversal_amount         = [3, 3].freeze
      @high_low_close          = ['high_low', 'close'].freeze
      @relative_strength_index = Indicators::RelativeStrengthIndex.new(candles: current_candles, count: RSI_COUNT)
    end

    include Strategies::Steps::Strategy49XX1
  end
end
