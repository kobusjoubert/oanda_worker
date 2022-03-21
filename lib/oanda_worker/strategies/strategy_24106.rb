module Strategies
  class Strategy24106 < Strategy
    INSTRUMENT       = INSTRUMENTS['USD_CHF']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['USD_CHF']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
