module Strategies
  class Strategy25106 < Strategy
    INSTRUMENT       = INSTRUMENTS['USD_CHF']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['USD_CHF']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy25XX0
  end
end
