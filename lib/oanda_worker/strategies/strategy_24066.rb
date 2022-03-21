module Strategies
  class Strategy24066 < Strategy
    INSTRUMENT       = INSTRUMENTS['GBP_CHF']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['GBP_CHF']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
