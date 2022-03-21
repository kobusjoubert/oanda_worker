module Strategies
  class Strategy24048 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_NZD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_NZD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
