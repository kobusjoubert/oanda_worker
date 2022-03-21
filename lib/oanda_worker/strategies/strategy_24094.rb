module Strategies
  class Strategy24094 < Strategy
    INSTRUMENT       = INSTRUMENTS['NZD_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NZD_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
