module Strategies
  class Strategy46024 < Strategy
    INSTRUMENT       = INSTRUMENTS['CHF_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['CHF_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 1.freeze

    attr_reader :risk_factor, :exit_factor, :box_size, :granularity, :reversal_amount, :high_low_close

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @risk_factor     = 500.freeze
      @exit_factor     = 18.freeze
      @granularity     = ['H1', 'D'].freeze
      @box_size        = [5, 5].freeze
      @reversal_amount = [3, 3].freeze
      @high_low_close  = ['high_low', 'close'].freeze
    end

    include Strategies::Steps::Strategy46XX2
  end
end
