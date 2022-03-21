# WIP
module Strategies
  class Strategy50058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    RSI_COUNT        = 14.freeze
    EMA_COUNT        = 9.freeze
    CANDLES_REQUIRED = 350.freeze
    MIN_TAKE_PROFIT  = 6.freeze
    MIN_STOP_LOSS    = 6.freeze
    MAX_STOP_LOSS    = 12.freeze

    attr_reader :relative_strength_index, :exponential_moving_average, :pips_required_for_entry, :stop_loss

    def step_1
      return true if self.oanda_trade = oanda_last_trade

      candles(smooth: false, include_incomplete_candles: true)

      @pips_required_for_entry    = 3 * PIP_SIZE
      @relative_strength_index    = Indicators::RelativeStrengthIndex.new(candles: candles, count: RSI_COUNT)
      @exponential_moving_average = Overlays::ExponentialMovingAverage.new(candles: candles, count: EMA_COUNT)

      if enter_long?
        self.close_at_entry = close
        @stop_loss = [MIN_STOP_LOSS, (close_at_entry - candles['candles'][-2]['mid']['l'].to_f).abs * (1 / PIP_SIZE) * 1.2].max
        @stop_loss = MAX_STOP_LOSS if stop_loss > MAX_STOP_LOSS
        backtest_logging
        return create_order_at_offset!(:long, order_pips: 0, take_profit_pips: +MIN_TAKE_PROFIT, stop_loss_pips: -stop_loss)
      end

      if enter_short?
        self.close_at_entry = close
        @stop_loss = [MIN_STOP_LOSS, (close_at_entry - candles['candles'][-2]['mid']['h'].to_f).abs * (1 / PIP_SIZE) * 1.2].max
        @stop_loss = MAX_STOP_LOSS if stop_loss > MAX_STOP_LOSS
        backtest_logging
        return create_order_at_offset!(:short, order_pips: 0, take_profit_pips: -MIN_TAKE_PROFIT, stop_loss_pips: +stop_loss)
      end

      false
    end

    private

    def backtest_logging
      return unless backtesting?
      message = "rsi: #{relative_strength_index.points[-2].round(4)}, movement: #{(exponential_moving_average.points[-2] - candles['candles'][-2]['mid']['o'].to_f).round(4).abs * 10_000}, sl: #{stop_loss.round(4)}"
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
      relative_strength_index.points[-2] < 20 &&
      (exponential_moving_average.points[-2] - candles['candles'][-2]['mid']['o'].to_f).abs > pips_required_for_entry &&
      candles['candles'][-2]['mid']['l'].to_f < candles['candles'][-1]['mid']['l'].to_f
    end

    def enter_short?
      relative_strength_index.points[-2] > 80 &&
      (exponential_moving_average.points[-2] - candles['candles'][-2]['mid']['o'].to_f).abs > pips_required_for_entry &&
      candles['candles'][-2]['mid']['h'].to_f > candles['candles'][-1]['mid']['h'].to_f
    end

    def cleanup
      $redis.del("#{key_base}:close_at_entry")
    end
  end
end
