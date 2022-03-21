module Strategies
  class Strategy24038 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_GBP']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_GBP']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
