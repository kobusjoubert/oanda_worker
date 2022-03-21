module Strategies
  class Strategy24002 < Strategy
    INSTRUMENT       = INSTRUMENTS['AUD_CHF']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['AUD_CHF']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
