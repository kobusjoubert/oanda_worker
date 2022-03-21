module Strategies
  class Strategy32059 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 120.freeze

    # Open 1 buy and 1 sell order at 06:00 if trend is favourable.
    # Set TP on first buy and sell orders.
    def step_1
      # TODO: Confirm that there aren't any orders placed already.
      # TESTING: Comment if condition only for testing!
      if time_inside?('06:01', '09:00', 'utc+2')
        self.close_at_entry = close
        return true if queue_next_run
      end

      false
    end

    # Buy order 1 with TP & SL.
    def step_2
      create_order_at_offset!(:long, order_pips: -7.5, take_profit_pips: +12, stop_loss_pips: -50) && queue_next_run ? true : false
    end

    # Sell order 1 with TP & SL.
    def step_3
      create_order_at_offset!(:short, order_pips: +7.5, take_profit_pips: -12, stop_loss_pips: +50) && queue_next_run ? true : false
    end

    # Close orders after 13:00.
    # If no trades triggered before 09:00, close all orders.
    # If 1 trade triggered before 09:00, close 1 opposite side order.
    def step_4
      unlock!([1, 2, 3])

      # TESTING: Comment this block for testing!
      if oanda_trades['trades'].empty? && time_outside?('06:01', '09:00', 'utc+2')
        exit_trades_and_orders!
        reset_steps
        return false
      end

      if oanda_trades['trades'].size > 0
        return true if queue_next_run
      end

      if oanda_orders['orders'].size < 2
        exit_trades_and_orders!
        wait_at_end
        return false
      end

      false
    end

    # Trade 1 triggered, close opposite side order.
    def step_5
      unlock!(4)
      return false if close_orders_after_exit_time && reset_steps
      return false if close_orders_when_trades_empty! && wait_at_end

      if oanda_short_orders.size < 1
        exit_orders!('long')
        return true if queue_next_run
      end

      if oanda_long_orders.size < 1
        exit_orders!('short')
        return true if queue_next_run
      end

      false
    end

    # Wait until 13:00 before resetting the strategy for the next day.
    def step_6
      unlock!([1, 2, 3, 4, 5])
      return true if close_orders_after_exit_time && cleanup
      false
    end

    private

    def options
      @options ||= {
        'order' => {
          'instrument' => instrument,
          'timeInForce' => 'GTC',
          'type' => 'MARKET_IF_TOUCHED',
          'positionFill' => 'DEFAULT',
          'clientExtensions' => {
            'tag' => self.class.to_s.downcase.split('::')[1]
          }
        }
      }
    end

    def cleanup
      unlock!(:all)
      $redis.del("#{key_base}:close_at_entry")
    end

    def close_orders_after_exit_time
      # return exit_trades_and_orders! if step > 9 && step < 14 # TESTING: Uncomment for testing!
      # return false # TESTING: Uncomment for testing!
      time_outside?('06:01', '13:00', 'utc+2') && exit_trades_and_orders!
    end

    def wait_at_end
      unlock!(:all)
      self.next_step = 6 # step_6
    end
  end
end
