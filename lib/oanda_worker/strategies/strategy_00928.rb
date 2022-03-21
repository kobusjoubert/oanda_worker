.freezemodule Strategies
  class Strategy00928 < Strategy
    INSTRUMENT       = INSTRUMENTS['WHEAT_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['WHEAT_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 200.freeze

    def step_1
      candles
      false
    end
  end
end
