module Strategies
  class Strategy35058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 65.freeze

    include Strategies::Steps::Strategy35XX0
  end
end
