module Strategies
  class Strategy24084 < Strategy
    INSTRUMENT       = INSTRUMENTS['NZD_CAD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NZD_CAD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
