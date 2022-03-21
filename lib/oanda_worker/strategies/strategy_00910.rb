module Strategies
  class Strategy00910 < Strategy
    INSTRUMENT       = INSTRUMENTS['SOYBN_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['SOYBN_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 200.freeze

    def step_1
      candles
      false
    end
  end
end
