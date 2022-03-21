module Strategies
  class Strategy24012 < Strategy
    INSTRUMENT       = INSTRUMENTS['AUD_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['AUD_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
