module Strategies
  class Strategy00902 < Strategy
    INSTRUMENT       = INSTRUMENTS['CORN_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['CORN_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 200.freeze

    def step_1
      candles
      false
    end
  end
end
