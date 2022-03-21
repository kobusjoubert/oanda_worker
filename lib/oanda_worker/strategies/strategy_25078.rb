module Strategies
  class Strategy25078 < Strategy
    INSTRUMENT       = INSTRUMENTS['GBP_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['GBP_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy25XX0
  end
end
