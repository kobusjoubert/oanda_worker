module Strategies
  module Steps
    module Strategy42XXX
      # 1) Kickstart using a long and short order with the same units each so we can start finding the xo trend.
      # 2) Every minute check if we have a trade, then exit previous orders and place new long and short orders.

      # Place first kickstart long order (3 x units).
      def step_1
        candles(smooth: false, include_incomplete_candles: true)
        options
        @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[0]).to_s
        order_price                = (current_close_box_price + (distance_apart.to_f / 2).ceil * box_size) * pip_size
        self.new_long_price        = order_price
        queue_next_run if create_order_at!('long', order_price: order_price)
      end

      # Place first kickstart short order (3 x units).
      def step_2
        candles(smooth: false, include_incomplete_candles: true)
        options
        @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[0]).to_s
        order_price                = (current_close_box_price - (distance_apart.to_f / 2).floor * box_size) * pip_size
        self.new_short_price       = order_price
        queue_next_run if create_order_at!('short', order_price: order_price)
      end

      # Wait for the first trade to trigger so we can start an xo trend.
      #
      #   If no orders and no trades reset_steps.
      #   If a trade triggered.
      #   Set XO trend by updating last_xo.
      #   Update new_long_price & new_short_price.
      #   Exit orders.
      def step_3
        return false if oanda_long_orders.empty? && oanda_short_orders.empty? && reset_steps
        return false if oanda_long_orders.one? && oanda_short_orders.one?
        raise OandaWorker::StrategyStepError, "More than 1 order in either direction! oanda_long_orders: #{oanda_long_orders.size}, oanda_short_orders: #{oanda_short_orders.size}" if oanda_long_orders.size > 1 || oanda_short_orders.size > 1

        return false unless oanda_trades['trades'].any?

        if oanda_long_trades.any?
          self.last_xo         = 'X'
          self.new_short_price = oanda_short_orders.last['price'].to_f + box_size * pip_size
          self.new_long_price  = new_short_price + distance_apart * box_size * pip_size

          while close > new_long_price
            self.new_short_price = new_short_price + box_size * pip_size
            self.new_long_price  = new_long_price + box_size * pip_size
          end
        end

        if oanda_short_trades.any?
          self.last_xo         = 'O'
          self.new_long_price  = oanda_long_orders.last['price'].to_f - box_size * pip_size
          self.new_short_price = new_long_price - distance_apart * box_size * pip_size

          while close < new_short_price
            self.new_long_price  = new_long_price - box_size * pip_size
            self.new_short_price = new_short_price - box_size * pip_size
          end
        end

        exit_orders!
        queue_next_run
      end

      # Place long order.
      #
      #   X trend --> 2 x units.
      #   O trend --> (3 x units x 2).
      def step_4
        options

        case last_xo
        when 'X'
          @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[1]).to_s
        when 'O' # Stop loss with new trade in opposite direction!
          @options['order']['units'] = (@options['order']['units'].to_i * (units_multiplier[0] * 2)).to_s
        end

        create_order_at!('long', order_price: new_long_price) && queue_next_run
      end

      # Place short order.
      #
      #   X trend --> (3 x units x 2).
      #   O trend --> 2 x units.
      def step_5
        options

        case last_xo
        when 'X' # Stop loss with new trade in opposite direction!
          @options['order']['units'] = (@options['order']['units'].to_i * (units_multiplier[0] * 2)).to_s
        when 'O'
          @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[1]).to_s
        end

        create_order_at!('short', order_price: new_short_price) && queue_next_run
      end

      # Wait for a trade to trigger.
      #
      #   If no orders, go to step 1.
      #   If two orders, return false.
      #   If one order, a trade must have triggered.
      #   Update last_xo, new_short_price & new_long_price.
      #   Exit opposite side order.
      #   If reversal, go to step 4 else go to next step.
      def step_6
        return false if oanda_long_orders.empty? && oanda_short_orders.empty? && reset_steps
        return false if oanda_long_orders.one? && oanda_short_orders.one?
        raise OandaWorker::StrategyStepError, "More than 1 order in either direction! oanda_long_orders: #{oanda_long_orders.size}, oanda_short_orders: #{oanda_short_orders.size}" if oanda_long_orders.size > 1 || oanda_short_orders.size > 1

        if oanda_long_orders.one? ^ oanda_short_orders.one?
          reversal = update_new_prices_and_last_xo
          exit_orders!

          if reversal
            self.next_step = 4
            return false if queue_next_run
          else
            return true if queue_next_run
          end
        end

        false
      end

      # Place long order.
      #
      #   X trend --> 1 x units.
      #   O trend --> (3 x units x 2) + 2 x units.
      def step_7
        options

        case last_xo
        when 'X'
          @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[2]).to_s
        when 'O' # Stop loss with new trade in opposite direction!
          @options['order']['units'] = (@options['order']['units'].to_i * (units_multiplier[0] * 2 + units_multiplier[1])).to_s
        end

        create_order_at!('long', order_price: new_long_price) && queue_next_run
      end

      # Place short order.
      #
      #   X trend --> (3 x units x 2) + 2 x units.
      #   O trend --> 1 x units.
      def step_8
        options

        case last_xo
        when 'X' # Stop loss with new trade in opposite direction!
          @options['order']['units'] = (@options['order']['units'].to_i * (units_multiplier[0] * 2 + units_multiplier[1])).to_s
        when 'O'
          @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[2]).to_s
        end

        create_order_at!('short', order_price: new_short_price) && queue_next_run
      end

      # Wait for a trade to trigger.
      #
      #   If no orders, go to step 1.
      #   If two orders, return false.
      #   If one order, a trade must have triggered.
      #   Update last_xo, new_short_price & new_long_price.
      #   Exit opposite side order.
      #   If reversal, go to step 4 else go to next step.
      def step_9
        return false if oanda_long_orders.empty? && oanda_short_orders.empty? && reset_steps
        return false if oanda_long_orders.one? && oanda_short_orders.one?
        raise OandaWorker::StrategyStepError, "More than 1 order in either direction! oanda_long_orders: #{oanda_long_orders.size}, oanda_short_orders: #{oanda_short_orders.size}" if oanda_long_orders.size > 1 || oanda_short_orders.size > 1

        if oanda_long_orders.one? ^ oanda_short_orders.one?
          reversal = update_new_prices_and_last_xo
          exit_orders!

          if reversal
            self.next_step = 4
            return false if queue_next_run
          else
            return true if queue_next_run
          end
        end

        false
      end

      # Place long order.
      #
      #   X trend --> 1 x units.
      #   O trend --> (3 x units x 2) + 2 x units + n x 1 units. (n starts at 1)
      def step_10
        options

        case last_xo
        when 'X'
          @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[2]).to_s
        when 'O' # Stop loss with new trade in opposite direction!
          @options['order']['units'] = (@options['order']['units'].to_i * (units_multiplier[0] * 2 + units_multiplier[1] + units_multiplier[2] * last_trend_increment)).to_s
        end

        create_order_at!('long', order_price: new_long_price) && queue_next_run
      end

      # Place short order.
      #
      #   X trend --> (3 x units x 2) + 2 x units + n x 1 units. (n starts at 1).
      #   O trend --> 1 x units.
      def step_11
        options

        case last_xo
        when 'X' # Stop loss with new trade in opposite direction!
          @options['order']['units'] = (@options['order']['units'].to_i * (units_multiplier[0] * 2 + units_multiplier[1] + units_multiplier[2] * last_trend_increment)).to_s
        when 'O'
          @options['order']['units'] = (@options['order']['units'].to_i * units_multiplier[2]).to_s
        end

        create_order_at!('short', order_price: new_short_price) && queue_next_run
      end

      # Wait for a trade to trigger.
      #
      #   If no orders, go to step 1.
      #   If two orders, return false.
      #   If one order, a trade must have triggered.
      #   Update last_xo, new_short_price & new_long_price.
      #   Exit opposite side order.
      #   If reversal, reset last_trend_increment and go to step 4 else increment last_trend_increment and go to step 10.
      def step_12
        return false if oanda_long_orders.empty? && oanda_short_orders.empty? && reset_steps
        return false if oanda_long_orders.one? && oanda_short_orders.one?
        raise OandaWorker::StrategyStepError, "More than 1 order in either direction! oanda_long_orders: #{oanda_long_orders.size}, oanda_short_orders: #{oanda_short_orders.size}" if oanda_long_orders.size > 1 || oanda_short_orders.size > 1

        if oanda_long_orders.one? ^ oanda_short_orders.one?
          reversal = update_new_prices_and_last_xo
          exit_orders!

          if reversal
            self.last_trend_increment = 1
            self.next_step            = 4
            return false if queue_next_run
          else
            self.last_trend_increment = last_trend_increment + 1
            self.next_step            = 10
            return false if queue_next_run
          end
        end

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
            'triggerCondition' => 'MID',
            'clientExtensions' => {
              'tag' => self.class.to_s.downcase.split('::')[1]
            }
          }
        }
      end

      # TODO: Call this method when stopping the strategy.
      def cleanup
        unlock!(:all)
        $redis.del("#{key_base}:last_xo")
        $redis.del("#{key_base}:last_trend_increment")
        $redis.del("#{key_base}:new_long_price")
        $redis.del("#{key_base}:new_short_price")
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

      # NOTE:
      #
      #   We work with integers because matching floating numbers to the current box prices is impossible.
      #   To accomplish this we simply devide the price by die pip size.
      #
      #   (1.04593 / 0.0001)  => 10459.3
      #   (10459.3).floor     => 10459

      def current_close_integer_price
        @current_close_integer_price ||= (candles['candles'].last['mid']['c'].to_f / pip_size).floor
      end

      def current_close_box_price
        @current_close_box_price ||= current_close_integer_price - current_close_integer_price % box_size
      end

      # It is important not to memoize becuase we ask for this value a second time after updating it in the same step.
      def last_xo
        $redis.get("#{key_base}:last_xo")
      end

      def last_xo=(value)
        $redis.set("#{key_base}:last_xo", value)
      end

      def last_trend_increment
        ($redis.get("#{key_base}:last_trend_increment") || 1).to_i
      end

      def last_trend_increment=(value)
        value = 1 if value.to_i == 0
        $redis.set("#{key_base}:last_trend_increment", value)
      end

      def new_short_price
        $redis.get("#{key_base}:new_short_price").to_f.round(round_decimal)
      end

      def new_short_price=(value)
        price = value.round(round_decimal)
        $redis.set("#{key_base}:new_short_price", price)
      end

      def new_long_price
        $redis.get("#{key_base}:new_long_price").to_f.round(round_decimal)
      end

      def new_long_price=(value)
        price = value.round(round_decimal)
        $redis.set("#{key_base}:new_long_price", price)
      end

      def update_new_prices_and_last_xo
        reversal         = false
        current_close    = close(include_incomplete_candles: true, refresh: true)
        last_trade_price = oanda_trades['trades'].first['price'].to_f

        case last_xo
        when 'X'
          if oanda_short_orders.one?
            self.new_short_price = oanda_short_orders.last['price'].to_f + box_size * pip_size
            self.new_long_price  = new_short_price + distance_apart * box_size * pip_size

            while [last_trade_price, current_close].max > new_long_price
              self.new_short_price = new_short_price + box_size * pip_size
              self.new_long_price  = new_long_price + box_size * pip_size
            end
          end

          if oanda_long_orders.one?
            reversal             = true
            self.last_xo         = 'O'
            self.new_long_price  = oanda_long_orders.last['price'].to_f - box_size * pip_size
            self.new_short_price = new_long_price - distance_apart * box_size * pip_size

            while [last_trade_price, current_close].min < new_short_price
              self.new_long_price  = new_long_price - box_size * pip_size
              self.new_short_price = new_short_price - box_size * pip_size
            end
          end
        when 'O'
          if oanda_long_orders.one?
            self.new_long_price  = oanda_long_orders.last['price'].to_f - box_size * pip_size
            self.new_short_price = new_long_price - distance_apart * box_size * pip_size

            while [last_trade_price, current_close].min < new_short_price
              self.new_long_price  = new_long_price - box_size * pip_size
              self.new_short_price = new_short_price - box_size * pip_size
            end
          end

          if oanda_short_orders.one?
            reversal             = true
            self.last_xo         = 'X'
            self.new_short_price = oanda_short_orders.last['price'].to_f + box_size * pip_size
            self.new_long_price  = new_short_price + distance_apart * box_size * pip_size

            while [last_trade_price, current_close].max > new_long_price
              self.new_short_price = new_short_price + box_size * pip_size
              self.new_long_price  = new_long_price + box_size * pip_size
            end
          end
        end

        reversal
      end
    end
  end
end
