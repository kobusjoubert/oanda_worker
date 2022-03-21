module Strategies
  class Strategy24078 < Strategy
    INSTRUMENT       = INSTRUMENTS['GBP_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['GBP_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
