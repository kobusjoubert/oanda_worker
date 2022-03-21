# WIP
module Strategies
  class Strategy40058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 2.freeze
    BOX_SIZE         = 20.freeze
    REVERSAL_AMOUNT  = 2.freeze
    STOP_LOSS        = 40.freeze

    attr_reader :pips_required_for_entry, :stop_loss

    def step_1
      return true if self.oanda_trade = oanda_last_trade

      candles(smooth: false, include_incomplete_candles: true)

      @pips_required_for_entry = 3 * PIP_SIZE

      if enter_long?
        self.close_at_entry = close
        backtest_logging
        return create_order_at_offset!(:long, order_pips: 0, take_profit_pips: +MIN_TAKE_PROFIT, stop_loss_pips: -STOP_LOSS)
      end

      if enter_short?
        self.close_at_entry = close
        backtest_logging
        return create_order_at_offset!(:short, order_pips: 0, take_profit_pips: -MIN_TAKE_PROFIT, stop_loss_pips: +STOP_LOSS)
      end

      false
    end

    private

    def backtest_logging
      return unless backtesting?
      message = '...'
      data = @data.merge({
        published_at: time_now_utc,
        level:        :warning,
        message:      message
      })
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
    end

    def options
      @options ||= {
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
    end

    def enter_long?
      true
      # candles['candles'][-2]['mid']['l'].to_f < candles['candles'][-1]['mid']['l'].to_f
    end

    def enter_short?
      false
      # candles['candles'][-2]['mid']['h'].to_f > candles['candles'][-1]['mid']['h'].to_f
    end

    def cleanup
      $redis.del("#{key_base}:close_at_entry")
    end
  end
end
