module Strategies
  class Strategy24032 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_CHF']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_CHF']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
