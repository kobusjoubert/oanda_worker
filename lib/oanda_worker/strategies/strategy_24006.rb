module Strategies
  class Strategy24006 < Strategy
    INSTRUMENT       = INSTRUMENTS['AUD_JPY']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['AUD_JPY']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
