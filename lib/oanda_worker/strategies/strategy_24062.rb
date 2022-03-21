module Strategies
  class Strategy24062 < Strategy
    INSTRUMENT       = INSTRUMENTS['GBP_AUD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['GBP_AUD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
