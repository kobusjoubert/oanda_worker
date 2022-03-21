module Strategies
  class Strategy30059 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 120.freeze

    # Open 3 buy and 3 sell orders at 06:00 if trend is favourable.
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

    # Buy order 1 with TP.
    def step_2
      create_order_at_offset!(:long, order_pips: -7.5, take_profit_pips: +12) && queue_next_run ? true : false
    end

    # Sell order 1 with TP.
    def step_3
      create_order_at_offset!(:short, order_pips: +7.5, take_profit_pips: -12) && queue_next_run ? true : false
    end

    # Buy order 2.
    def step_4
      create_order_at_offset!(:long, order_pips: -19.5) && queue_next_run ? true : false
    end

    # Sell order 2.
    def step_5
      create_order_at_offset!(:short, order_pips: +19.5) && queue_next_run ? true : false
    end

    # Buy order 3.
    def step_6
      create_order_at_offset!(:long, order_pips: -39) && queue_next_run ? true : false
    end

    # Sell order 3.
    def step_7
      create_order_at_offset!(:short, order_pips: +39) && queue_next_run ? true : false
    end

    # Close orders after 13:00.
    # If no trades triggered before 09:00, close all orders.
    # If 1 trade triggered before 09:00, close 3 opposite side orders.
    # If 2 trades triggered, update TP on trades 1 & 2.
    # If 3 trades triggered, update TP on trades 1, 2 & 3 and update SL on 3 trades.
    def step_8
      unlock!([1, 2, 3, 4, 5, 6, 7])

      # TESTING: Comment this block for testing!
      if oanda_trades['trades'].empty? && time_outside?('06:01', '09:00', 'utc+2')
        exit_trades_and_orders!
        reset_steps
        return false
      end

      if oanda_trades['trades'].size > 0
        return true if queue_next_run
      end

      if oanda_orders['orders'].size < 6
        exit_trades_and_orders!
        wait_at_end
        return false
      end

      false
    end

    # Trade 1 triggered, close opposite side orders.
    def step_9
      unlock!(8)
      return false if close_orders_after_exit_time && reset_steps
      return false if close_orders_when_trades_empty! && wait_at_end

      if oanda_short_orders.size < 3
        exit_orders!('long')
        return true if queue_next_run
      end

      if oanda_long_orders.size < 3
        exit_orders!('short')
        return true if queue_next_run
      end

      false
    end

    # Wait for trade 2 or 3 to trigger before carrying on.
    def step_10
      unlock!(9)
      return false if close_orders_after_exit_time && reset_steps
      return false if close_orders_when_trades_empty! && wait_at_end

      # 2 trades triggered.
      if oanda_trades['trades'].size == 2
        return true if queue_next_run
      end

      # 3 trades triggered.
      if oanda_trades['trades'].size == 3
        self.next_step = step + 3 # step_13
        return false if queue_next_run
      end

      false
    end

    # Trade 2 triggered, update TPs.
    def step_11
      unlock!(10)
      return false if close_orders_after_exit_time && reset_steps
      return false if close_orders_when_trades_empty! && wait_at_end

      # 3 trades triggered.
      if oanda_trades['trades'].size == 3
        self.next_step = step + 2 # step_13
        return false if queue_next_run
      end

      return false unless type = oanda_trade_type

      take_profit = 15 * PIP_SIZE

      case type
      when 'long'
        take_profit_price = close_at_entry - 19.5 * PIP_SIZE + take_profit
      when 'short'
        take_profit_price = close_at_entry + 19.5 * PIP_SIZE - take_profit
      end

      counter = 0

      oanda_trades['trades'].each do |trade|
        options = {
          id:          trade['id'],
          take_profit: take_profit_price.round(round_decimal)
        }

        update_trade!(options)
        counter += 1
      end

      return true if counter == 2
      false
    end

    # Wait for trade 3 to trigger before carrying on.
    def step_12
      unlock!(11)
      return false if close_orders_after_exit_time && reset_steps
      return false if close_orders_when_trades_empty! && wait_at_end

      # 3 trades triggered.
      if oanda_trades['trades'].size == 3
        return true if queue_next_run
      end

      false
    end

    # Trade 3 triggered, update TPs and SLs.
    def step_13
      unlock!([10, 11, 12])
      return false if close_orders_after_exit_time && reset_steps
      return false if close_orders_when_trades_empty! && wait_at_end
      return false unless type = oanda_trade_type

      take_profit = 25.5 * PIP_SIZE

      case type
      when 'long'
        stop_loss         = -250 * PIP_SIZE
        take_profit_price = close_at_entry - 39 * PIP_SIZE + take_profit
      when 'short'
        stop_loss         = 250 * PIP_SIZE
        take_profit_price = close_at_entry + 39 * PIP_SIZE - take_profit
      end

      stop_loss_price = close_at_entry + stop_loss
      counter         = 0

      oanda_trades['trades'].each do |trade|
        options = {
          id:          trade['id'],
          take_profit: take_profit_price.round(round_decimal),
          stop_loss:   stop_loss_price.round(round_decimal)
        }

        update_trade!(options)
        counter += 1
      end

      return true if counter == 3
      false
    end

    # Wait until 13:00 before resetting the strategy for the next day.
    def step_14
      unlock!([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
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
      self.next_step = 14 # step_14
    end
  end
end
