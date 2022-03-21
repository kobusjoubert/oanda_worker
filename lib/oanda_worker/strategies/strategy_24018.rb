module Strategies
  class Strategy24018 < Strategy
    INSTRUMENT       = INSTRUMENTS['CAD_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['CAD_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
