module Strategies
  class Strategy25044 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy25XX0
  end
end
