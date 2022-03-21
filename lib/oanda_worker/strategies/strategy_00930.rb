module Strategies
  class Strategy00930 < Strategy
    INSTRUMENT       = INSTRUMENTS['WTICO_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['WTICO_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 200.freeze

    def step_1
      candles
      false
    end
  end
end
