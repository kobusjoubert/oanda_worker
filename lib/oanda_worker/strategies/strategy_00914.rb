module Strategies
  class Strategy00914 < Strategy
    INSTRUMENT       = INSTRUMENTS['SUGAR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['SUGAR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 200.freeze

    def step_1
      candles
      false
    end
  end
end
