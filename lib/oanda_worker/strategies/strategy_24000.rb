module Strategies
  class Strategy24000 < Strategy
    INSTRUMENT       = INSTRUMENTS['AUD_CAD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['AUD_CAD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
