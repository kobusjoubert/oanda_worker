module Strategies
  class Strategy24044 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
