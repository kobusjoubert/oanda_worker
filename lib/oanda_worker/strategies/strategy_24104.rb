module Strategies
  class Strategy24104 < Strategy
    INSTRUMENT       = INSTRUMENTS['USD_CAD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['USD_CAD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
