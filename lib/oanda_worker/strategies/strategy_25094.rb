module Strategies
  class Strategy25094 < Strategy
    INSTRUMENT       = INSTRUMENTS['NZD_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NZD_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy25XX0
  end
end
