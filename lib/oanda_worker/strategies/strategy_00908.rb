module Strategies
  class Strategy00908 < Strategy
    INSTRUMENT       = INSTRUMENTS['NATGAS_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NATGAS_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 200.freeze

    def step_1
      candles
      false
    end
  end
end
