module Strategies
  class Strategy02930 < Strategy
    INSTRUMENT       = INSTRUMENTS['WTICO_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['WTICO_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 2.freeze

    def step_1
      @options = {
        'order' => {
          'instrument' => instrument,
          'timeInForce' => 'FOK',
          'type' => 'MARKET',
          'positionFill' => 'DEFAULT',
          'clientExtensions' => {
            'tag' => self.class.to_s.downcase.split('::')[1]
          }
        }
      }

      if enter_long?
        exit_trade!
        return create_long_order!
      end

      if enter_short?
        exit_trade!
        return create_short_order!
      end

      false
    end

    private

    def enter_long?
      if self.oanda_trade = oanda_last_trade
        return false if oanda_trade_type == 'long'
      end

      candles['candles'][0]['mid']['c'].to_f < candles['candles'][0]['mid']['o'].to_f &&
      candles['candles'][1]['mid']['c'].to_f > candles['candles'][1]['mid']['o'].to_f
    end

    def enter_short?
      if self.oanda_trade = oanda_last_trade
        return false if oanda_trade_type == 'short'
      end

      candles['candles'][0]['mid']['c'].to_f > candles['candles'][0]['mid']['o'].to_f &&
      candles['candles'][1]['mid']['c'].to_f < candles['candles'][1]['mid']['o'].to_f
    end
  end
end
