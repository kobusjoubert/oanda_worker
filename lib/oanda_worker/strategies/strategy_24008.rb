module Strategies
  class Strategy24008 < Strategy
    INSTRUMENT       = INSTRUMENTS['AUD_NZD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['AUD_NZD']['pip_size'].freeze
    CANDLES_REQUIRED = 50.freeze

    include Strategies::Steps::Strategy24XX0
  end
end
