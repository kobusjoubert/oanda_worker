module Strategies
  class Strategy24090 < Strategy
    INSTRUMENT       = INSTRUMENTS['NZD_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NZD_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
