module Strategies
  class Strategy24072 < Strategy
    INSTRUMENT       = INSTRUMENTS['GBP_NZD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['GBP_NZD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
