module Strategies
  class Strategy24070 < Strategy
    INSTRUMENT       = INSTRUMENTS['GBP_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['GBP_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
