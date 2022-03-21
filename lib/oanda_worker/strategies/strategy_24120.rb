module Strategies
  class Strategy24120 < Strategy
    INSTRUMENT       = INSTRUMENTS['USD_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['USD_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
