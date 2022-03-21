module Strategies
  module Steps
    module Strategy45XXX
      # Wait for buy or sell signal.
      # Create order with stop loss.
      def step_1
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(4) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(2) && queue_next_run

        if create_long_order?
          return create_long_order! && queue_next_run
        end

        if create_short_order?
          return create_short_order! && queue_next_run
        end

        false
      end

      # 1 Order.
      # Update stop loss.
      # Cancel order when risk is too high.
      def step_2
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(4) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && reset_steps && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 order! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 1

        if oanda_long_orders.any?
          return false if cancel_long_order? && exit_orders!('long') && reset_steps && queue_next_run
          order = oanda_long_orders.last
          update_long_order!(order)
        end

        if oanda_short_orders.any?
          return false if cancel_short_order? && exit_orders!('short') && reset_steps && queue_next_run
          order = oanda_short_orders.last
          update_short_order!(order)
        end

        false
      end

      # 1 Trade.
      # Update stop loss.
      # Exit trade if contract has risen or fallen 18 consecutive boxes.
      # Create short order when currently trading long and short order conditions are met and vice versa.
      def step_3
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(4) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && reset_steps && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1

        if oanda_long_trades.any?
          trade = oanda_long_trades.last
          update_long_trade!(trade)

          if exit_long_trade?(trade)
            return false if exit_trades_and_orders! && reset_steps && queue_next_run
          end

          if create_short_order?
            return create_short_order! && queue_next_run
          end
        end

        if oanda_short_trades.any?
          trade = oanda_short_trades.last
          update_short_trade!(trade)

          if exit_short_trade?(trade)
            return false if exit_trades_and_orders! && reset_steps && queue_next_run
          end

          if create_long_order?
            return create_long_order! && queue_next_run
          end
        end

        false
      end

      # 1 Trade.
      # Update stop loss.
      # Exit trade if contract has risen or fallen 18 consecutive boxes.
      # 1 Order.
      # Update stop loss.
      # Cancel order when risk is too high.
      def step_4
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && reset_steps && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 order! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 1
        raise OandaWorker::StrategyStepError, "More than 1 trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1

        if oanda_long_trades.any?
          trade = oanda_long_trades.last
          update_long_trade!(trade)

          if exit_long_trade?(trade)
            return false if exit_trades_and_orders! && step_to(2) && queue_next_run
          end
        end

        if oanda_short_trades.any?
          trade = oanda_short_trades.last
          update_short_trade!(trade)

          if exit_short_trade?(trade)
            return false if exit_trades_and_orders! && step_to(2) && queue_next_run
          end
        end

        if oanda_long_orders.any?
          return false if cancel_long_order? && exit_orders!('long') && step_to(3) && queue_next_run
          order = oanda_long_orders.last
          update_long_order!(order)
        end

        if oanda_short_orders.any?
          return false if cancel_short_order? && exit_orders!('short') && step_to(3) && queue_next_run
          order = oanda_short_orders.last
          update_short_order!(order)
        end

        false
      end

      private

      def create_long_order!
        if current_xo == 'o'
          order_price     = (xos[-1].first['xo_price'] + 2 * box_size * pip_size).round(round_decimal)
          order_stop_loss = -((xos[-1].last['xo_length'] + 2) * box_size)
        end

        if current_xo == 'x'
          order_price     = (xos[-2].first['xo_price'] + 2 * box_size * pip_size).round(round_decimal)
          order_stop_loss = -((xos[-2].last['xo_length'] + 2) * box_size)
        end

        return create_order_at!('long', order_price: order_price, stop_loss_pips: order_stop_loss)
      end

      def create_short_order!
        if current_xo == 'x'
          order_price     = (xos[-1].first['xo_price'] - 2 * box_size * pip_size).round(round_decimal)
          order_stop_loss = +((xos[-1].last['xo_length'] + 2) * box_size)
        end

        if current_xo == 'o'
          order_price     = (xos[-2].first['xo_price'] - 2 * box_size * pip_size).round(round_decimal)
          order_stop_loss = +((xos[-2].last['xo_length'] + 2) * box_size)
        end

        return create_order_at!('short', order_price: order_price, stop_loss_pips: order_stop_loss)
      end

      def update_long_order!(order)
        order_stop_loss_price = order['stopLossOnFill']['price'].to_f.round(round_decimal)

        if current_xo == 'o'
          xo_stop_loss_price = (xos[-1].last['xo_price'] - 1 * box_size * pip_size).round(round_decimal)

          if xo_stop_loss_price < order_stop_loss_price
            update_order_at!('long', order['id'], order_price: order['price'].to_f, stop_loss_price: xo_stop_loss_price)
          end
        end
      end

      def update_short_order!(order)
        order_stop_loss_price = order['stopLossOnFill']['price'].to_f.round(round_decimal)

        if current_xo == 'x'
          xo_stop_loss_price = (xos[-1].last['xo_price'] + 1 * box_size * pip_size).round(round_decimal)

          if xo_stop_loss_price > order_stop_loss_price
            update_order_at!('short', order['id'], order_price: order['price'].to_f, stop_loss_price: xo_stop_loss_price)
          end
        end
      end

      def update_long_trade!(trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
        trade_stop_loss_price = trade['stopLossOrder']['price'].to_f.round(round_decimal)

        if current_xo == 'x'
          xo_stop_loss_price = (xos[-1].first['xo_price'] - 2 * box_size * pip_size).round(round_decimal)

          if xo_stop_loss_price > trade_stop_loss_price
            trade_options = {
              id:        trade['id'],
              stop_loss: xo_stop_loss_price.round(round_decimal)
            }

            update_trade!(trade_options)
          end
        end
      end

      def update_short_trade!(trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
        trade_stop_loss_price = trade['stopLossOrder']['price'].to_f.round(round_decimal)

        if current_xo == 'o'
          xo_stop_loss_price = (xos[-1].first['xo_price'] + 2 * box_size * pip_size).round(round_decimal)

          if xo_stop_loss_price < trade_stop_loss_price
            trade_options = {
              id:        trade['id'],
              stop_loss: xo_stop_loss_price.round(round_decimal)
            }

            update_trade!(trade_options)
          end
        end
      end

      def create_long_order?
        return false if current_trend == 'down'

        if current_xo == 'o'
          return true if xos[-1].last['xo_length'] <= risk_factor
        end

        if current_xo == 'x'
          return true if xos[-2].last['xo_length'] <= risk_factor && current_close < (xos[-3].last['xo_price'] + 1 * box_size * pip_size).round(round_decimal)
        end

        false
      end

      def create_short_order?
        return false if current_trend == 'up'

        if current_xo == 'x'
          return true if xos[-1].last['xo_length'] <= risk_factor
        end

        if current_xo == 'o'
          return true if xos[-2].last['xo_length'] <= risk_factor && current_close > (xos[-3].last['xo_price'] - 1 * box_size * pip_size).round(round_decimal)
        end

        false
      end

      def cancel_long_order?
        return true if current_trend == 'down'

        if current_xo == 'o'
          return true if xos[-1].last['xo_length'] > risk_factor
        end

        false
      end

      def cancel_short_order?
        return true if current_trend == 'up'

        if current_xo == 'x'
          return true if xos[-1].last['xo_length'] > risk_factor
        end

        false
      end

      def exit_long_trade?(trade)
        return false if current_xo == 'x'

        if current_xo == 'o' && xos[-2].last['xo_length'] >= 18
          # 18 - 1 because the trade price will not always be spot on with the box price the order was placed on.
          if xos[-2].last['xo_price'] >= (trade['price'].to_f + 17 * box_size * pip_size).round(round_decimal) && xos[-1].last['xo_price'] > trade['price'].to_f
            return true
          end
        end

        false
      end

      def exit_short_trade?(trade)
        return false if current_xo == 'o'

        if current_xo == 'x' && xos[-2].last['xo_length'] >= 18
          # 18 - 1 because the trade price will not always be spot on with the box price the order was placed on.
          if xos[-2].last['xo_price'] <= (trade['price'].to_f - 17 * box_size * pip_size).round(round_decimal) && xos[-1].last['xo_price'] < trade['price'].to_f
            return true
          end
        end

        false
      end

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

      def indicator_options
        @indicator_options ||= {
          instrument: instrument,
          granularity: granularity,
          box_size: box_size,
          reversal_amount: 3,
          count: 150
        }
      end

      def cleanup
        unlock!(:all)
      end

      def backtest_logging(message)
        return unless backtesting?
        data = @data.merge({
          published_at: time_now_utc,
          level:        :warning,
          message:      message
        })
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      end

      def indicator
        @indicator ||= oanda_service_client.indicator(:point_and_figure, indicator_options).show
        raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. indicator['data']: #{@indicator['data']}" if @indicator['data'].empty?
        @indicator
      end

      # Builds a multi dimensional array from the price records returned from the OandaService API.
      # This is used to determine where double top and bottom breakouts will occur so we can place our orders.
      #
      #   [
      #     [
      #       { 'xo_price' => 1.1, 'xo_length' => 1, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.2, 'xo_length' => 2, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.3, 'xo_length' => 3, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.4, 'xo_length' => 4, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.5, 'xo_length' => 5, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil }
      #     ],
      #     [
      #       { 'xo_price' => 1.4, 'xo_length' => 1, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.3, 'xo_length' => 2, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.2, 'xo_length' => 3, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil }
      #     ],
      #     [
      #       { 'xo_price' => 1.3, 'xo_length' => 1, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.4, 'xo_length' => 2, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.5, 'xo_length' => 3, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil }
      #     ],
      #     [
      #       { 'xo_price' => 1.4, 'xo_length' => 1, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.3, 'xo_length' => 2, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.2, 'xo_length' => 3, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil }
      #     ],
      #     [
      #       { 'xo_price' => 1.3, 'xo_length' => 1, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.4, 'xo_length' => 2, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.5, 'xo_length' => 3, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
      #       { 'xo_price' => 1.6, 'xo_length' => 4, 'xo' => 'x', 'trend' => 'up', 'pattern' => 'double_top' },
      #       { 'xo_price' => 1.7, 'xo_length' => 5, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil }
      #     ]
      #   ]
      def xos
        @xos ||= begin
          keys    = ['xo_price', 'xo_length', 'xo', 'trend', 'pattern']
          xos     = []
          xs      = []
          os      = []
          last_xo = points.last['xo']

          points.each do |point|
            case point['xo']
            when 'x'
              xs << point.select { |key, value| keys.include?(key) }

              if last_xo != point['xo']
                xos << os if os.any?
                os = []
              end
            when 'o'
              os << point.select { |key, value| keys.include?(key) }

              if last_xo != point['xo']
                xos << xs if xs.any?
                xs = []
              end
            end

            last_xo = point['xo']
          end

          xos << xs if xs.any?
          xos << os if os.any?
          xs = []
          os = []

          # We need at least 3 complete xo columns!
          raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough xo columns to work with. xos: #{xos.size}" if xos.size < 4
          xos
        end
      end

      def current_close
        @current_close ||= close(include_incomplete_candles: true, refresh: true)
      end

      def current_xo
        @current_xo ||= xos.last.last['xo']
      end

      def current_trend
        @current_trend ||= xos.last.last['trend']
      end

      def current_point
        @current_point ||= indicator['data'].last['attributes']
      end

      def points
        @points ||= indicator['data'].map{ |point| point['attributes'] }
      end
    end
  end
end
