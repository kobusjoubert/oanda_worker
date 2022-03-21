module Strategies
  class Strategy24086 < Strategy
    INSTRUMENT       = INSTRUMENTS['NZD_CHF']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NZD_CHF']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
