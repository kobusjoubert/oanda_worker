module Strategies
  class Strategy24138 < Strategy
    INSTRUMENT       = INSTRUMENTS['USD_ZAR']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['USD_ZAR']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
