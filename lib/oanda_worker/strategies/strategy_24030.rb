module Strategies
  class Strategy24030 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_CAD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_CAD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
