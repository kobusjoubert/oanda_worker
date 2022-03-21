module Strategies
  class Strategy24064 < Strategy
    INSTRUMENT       = INSTRUMENTS['GBP_CAD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['GBP_CAD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
