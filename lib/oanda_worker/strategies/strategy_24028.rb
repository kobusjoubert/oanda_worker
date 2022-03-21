module Strategies
  class Strategy24028 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_AUD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_AUD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
