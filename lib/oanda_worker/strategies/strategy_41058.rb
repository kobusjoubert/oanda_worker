module Strategies
  class Strategy41058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 2.freeze
    BOX_SIZE         = 20.freeze # In pips
    REVERSAL_AMOUNT  = 3.freeze  # In box sizes
    STOP_LOSS        = 35.freeze # In pips

    # 1) Check current XO, initialize as X
    # 2) Place short order on first reversal amount with stop_loss
    # 3) Every minute check:
    # If we have a short trade, then place a long order at the reversal_amount * box_size.
    # If we have a short trade and the last_box_price has moved down, update the stop_loss on the short trade. Also update the long order and its stop_loss, move it down.
    # If we don't have a trade but we have an order and if the last_box_price has moved up, update the short order and its stop_loss. Do not update if the price has moved down.

    # Place first orders with stop losses.
    #
    #   Place first long and short orders and queue next run.
    def step_1
      options
      @options['order']['units'] = '1'

      order_price = (current_close_box_price + REVERSAL_AMOUNT * BOX_SIZE) * PIP_SIZE
      create_order_at!('long', order_price: order_price, stop_loss_pips: -STOP_LOSS)
      order_price = current_close_box_price * PIP_SIZE
      create_order_at!('short', order_price: order_price, stop_loss_pips: STOP_LOSS)

      queue_next_run ? true : false
    end

    # Wait for the first trade to trigger so we can start an xo trend.
    #
    #   If no order and no trade reset_steps.
    #   If one trade, set xo trend and skip next step.
    def step_2
      unlock!(1)
      return false if oanda_trades['trades'].empty? && oanda_orders['orders'].empty? && reset_steps

      if oanda_trades['trades'].any? && exit_orders!
        if oanda_long_trades.any?
          self.last_xo        = 'X'
          self.last_box_price = (oanda_long_trades.first['stopLossOrder']['price'].to_f / PIP_SIZE).floor + STOP_LOSS
        end

        if oanda_short_trades.any?
          self.last_xo        = 'O'
          self.last_box_price = (oanda_short_trades.first['stopLossOrder']['price'].to_f / PIP_SIZE).floor - STOP_LOSS
        end

        self.next_step = 4
        queue_next_run
        return false
      end

      false
    end

    # Wait for a trade to trigger.
    #
    #   If no order and no trade go to step 4.
    #   Update last_xo and last_box_price.
    #   If one trade queue_next_run.
    #   If one order and no trade return false.
    def step_3
      unlock!([2, 5])
      return false if oanda_trades['trades'].empty? && oanda_orders['orders'].empty? && self.next_step = 4

      candles(smooth: false, include_incomplete_candles: true)
      old_box_price = last_box_price
      old_xo        = last_xo
      update_last_box_price_and_xo
      new_box_price = last_box_price
      new_xo        = last_xo

      return true if oanda_trades['trades'].any? && queue_next_run

      if oanda_trades['trades'].empty? && (oanda_long_orders.any? || oanda_short_orders.any?)
        case old_xo
        when 'X'
          if new_box_price > old_box_price
            order_type      = 'short'
            order_price     = (new_box_price - REVERSAL_AMOUNT * BOX_SIZE + BOX_SIZE) * PIP_SIZE
            order_stop_loss = STOP_LOSS
          end
        when 'O'
          if new_box_price < old_box_price
            order_type      = 'long'
            order_price     = (new_box_price + REVERSAL_AMOUNT * BOX_SIZE) * PIP_SIZE
            order_stop_loss = -STOP_LOSS
          end
        end

        if new_box_price != old_box_price
          # TODO: Use the Oanda API update order endpoint instead of cancelling an order and recreating a new order with 2 API calls. Remember to update the oanda_api_v20_backtest gem.
          exit_orders!
          create_order_at!(order_type, order_price: order_price, stop_loss_pips: order_stop_loss)
        end

        return false
      end

      false
    end

    # Place opposite side order.
    #
    #   Update last_xo and last_box_price.
    #   Place opposite side order with stop_loss.
    def step_4
      unlock!([2, 3, 5])

      candles(smooth: false, include_incomplete_candles: true)
      update_last_box_price_and_xo

      case last_xo
      when 'X'
        type        = 'short'
        order_price = (last_box_price - REVERSAL_AMOUNT * BOX_SIZE + BOX_SIZE) * PIP_SIZE
        stop_loss   = STOP_LOSS
      when 'O'
        type = 'long'
        order_price = (last_box_price + REVERSAL_AMOUNT * BOX_SIZE) * PIP_SIZE
        stop_loss   = -STOP_LOSS
      end

      create_order_at!(type, order_price: order_price, stop_loss_pips: stop_loss) && queue_next_run ? true : false
    end

    # Monitor trade and opposite side order.
    #
    #   If no order and no trade go to step 4.
    #   If trade stopped out, go to step_2.
    #   Update last_xo and last_box_price.
    #   If last_box_price has moved, update stop_loss on oanda_trade and update order and its stop_loss.
    #   If we have a short trade and the last_box_price has moved down, move the stop_loss down. Also move the long order and its stop_loss down.
    def step_5
      unlock!(4)
      return false if oanda_trades['trades'].empty? && oanda_orders['orders'].empty? && self.next_step = 4

      if oanda_trades['trades'].empty?
        self.next_step = 3
        return false if queue_next_run
      end

      candles(smooth: false, include_incomplete_candles: true)
      old_box_price = last_box_price
      old_xo        = last_xo
      update_last_box_price_and_xo
      new_box_price = last_box_price
      new_xo        = last_xo

      case old_xo
      when 'X'
        if new_box_price > old_box_price
          trade_id              = oanda_long_trades.first['id']
          trade_stop_loss_price = (new_box_price - STOP_LOSS + BOX_SIZE) * PIP_SIZE
          order_type            = 'short'
          order_price           = (new_box_price - REVERSAL_AMOUNT * BOX_SIZE + BOX_SIZE) * PIP_SIZE
          order_stop_loss       = STOP_LOSS
        end
      when 'O'
        if new_box_price < old_box_price
          trade_id              = oanda_short_trades.first['id']
          trade_stop_loss_price = (new_box_price + STOP_LOSS) * PIP_SIZE
          order_type            = 'long'
          order_price           = (new_box_price + REVERSAL_AMOUNT * BOX_SIZE) * PIP_SIZE
          order_stop_loss       = -STOP_LOSS
        end
      end

      if new_box_price != old_box_price
        trade_options = {
          id:        trade_id,
          stop_loss: trade_stop_loss_price.round(round_decimal)
        }

        update_trade!(trade_options)

        # TODO: Use the Oanda API update order endpoint instead of cancelling an order and recreating a new order with 2 API calls. Remember to update the oanda_api_v20_backtest gem.
        exit_orders!
        create_order_at!(order_type, order_price: order_price, stop_loss_pips: order_stop_loss)
      end

      false
    end

    private

    # NOTE:
    #
    #   We work with integers because matching floating numbers to the current box prices is impossible.
    #   To accomplish this we simply devide the price by die pip size.
    #
    #   (1.04593 / 0.0001)  => 10459.3
    #   (10459.3).floor     => 10459

    def current_high
      @current_high ||= (candles['candles'][-1]['mid']['h'].to_f / PIP_SIZE).floor
    end

    def current_low
      @current_low ||= (candles['candles'][-1]['mid']['l'].to_f / PIP_SIZE).floor
    end

    def current_close
      @current_close ||= (candles['candles'][-1]['mid']['c'].to_f / PIP_SIZE).floor
    end

    def current_high_box_price
      @current_high_box_price ||= (current_high - current_high % BOX_SIZE) - BOX_SIZE
    end

    def current_low_box_price
      @current_low_box_price ||= (current_low - current_low % BOX_SIZE) + BOX_SIZE
    end

    def current_close_box_price
      @current_close_box_price ||= current_close - current_close % BOX_SIZE
    end

    def update_last_box_price_and_xo
      case last_xo
      when 'X'
        if current_high_box_price > last_box_price
          self.last_box_price = current_high_box_price
        end

        if current_low_box_price <= last_box_price - (REVERSAL_AMOUNT * BOX_SIZE) + BOX_SIZE
          self.last_box_price = current_low_box_price
          self.last_xo = 'O'
        end
      when 'O'
        if current_low_box_price < last_box_price
          self.last_box_price = current_low_box_price
        end

        if current_high_box_price >= last_box_price + (REVERSAL_AMOUNT * BOX_SIZE) - BOX_SIZE
          self.last_box_price = current_high_box_price
          self.last_xo = 'X'
        end
      end
    end

    def current_xo
      @current_xo =
        case last_xo
        when 'X'
          return 'X' if current_high_box_price > last_box_price
          return 'O' if current_low_box_price <= last_box_price - (REVERSAL_AMOUNT * BOX_SIZE)
        when 'O'
          return 'O' if current_low_box_price < last_box_price
          return 'X' if current_high_box_price >= last_box_price + (REVERSAL_AMOUNT * BOX_SIZE)
        else
          last_xo
        end
    end

    # It is important not to memoize becuase we ask for this value a second time after updating it in the same step.
    def last_xo
      @last_xo = $redis.get("#{key_base}:last_xo")
    end

    def last_xo=(value)
      $redis.set("#{key_base}:last_xo", value)
    end

    # Be carefull, if it was not set before we will get a 0!
    # It is important not to memoize becuase we ask for this value a second time after updating it in the same step.
    def last_box_price
      @last_box_price = $redis.get("#{key_base}:last_box_price").to_i
    end

    def last_box_price=(value)
      $redis.set("#{key_base}:last_box_price", value.to_i)
    end

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
      $redis.del("#{key_base}:last_xo")
      $redis.del("#{key_base}:last_box_price")
    end
  end
end
