module Strategies
  class Strategy24014 < Strategy
    INSTRUMENT       = INSTRUMENTS['CAD_CHF']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['CAD_CHF']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
