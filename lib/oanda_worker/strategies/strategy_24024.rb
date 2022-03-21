module Strategies
  class Strategy24024 < Strategy
    INSTRUMENT       = INSTRUMENTS['CHF_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['CHF_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
