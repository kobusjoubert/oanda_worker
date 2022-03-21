module Strategies
  class Strategy80024 < Strategy
    INSTRUMENT       = INSTRUMENTS['CHF_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['CHF_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 300.freeze

    include Strategies::Steps::Strategy80XX0 # @targets = [0.382, 0.618].freeze
    # include Strategies::Steps::Strategy80XX1 # @targets = [0.382, :tsl].freeze
    # include Strategies::Steps::Strategy80XX2 # @targets = [0.382].freeze
  end
end
