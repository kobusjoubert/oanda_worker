# Strategy23XX0
#
#   Kobi.
#   Uses exponential moving averages crossing as indicator for trade, and ichimoku cloud as take profit level indicator.
#
# To enter a trade:
#
#   When the fast ema cross over the slow ema, a long trade is triggered.
#   When the fast ema cross under the slow ema, a short trade is triggered.
#   The take profit is calculated according to the ichimoku cloud span.
#
# To exit a trade:
#
#   Wait for a take profit to trigger.
#   Wait until exit time and exit all trades for the day.
#
module Strategies
  module Steps
    module Strategy23XX0
      # 0 Trades & 0 Orders.
      # Wait for trigger condition.
      def step_1
        return false if oanda_active_trades.size == 1 && step_to(2) && queue_next_run
        return false if time_outside?('04:01', '21:00', 'utc+2')

        trade_options

        if enter_long?
          backtest_logging("ichimoku_cloud: #{((ichimoku_cloud.senkou_span_a - ichimoku_cloud.senkou_span_b).abs / pip_size).round(round_decimal)}, take_profit_pips: #{take_profit_pips}, max_stop_loss_pips: #{max_stop_loss_pips}")

          take_profit = take_profit_pips * pip_size
          stop_loss   = max_stop_loss_pips * pip_size

          if create_order_at!(:long)
            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f + take_profit).round(round_decimal),
              stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f - stop_loss).round(round_decimal)
            }

            update_trade!(options)
            return true if queue_next_run
          end
        end

        if enter_short?
          backtest_logging("ichimoku_cloud: #{((ichimoku_cloud.senkou_span_a - ichimoku_cloud.senkou_span_b).abs / pip_size).round(round_decimal)}, take_profit_pips: #{take_profit_pips}, max_stop_loss_pips: #{max_stop_loss_pips}")

          take_profit = take_profit_pips * pip_size
          stop_loss   = max_stop_loss_pips * pip_size

          if create_order_at!(:short)
            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f - take_profit).round(round_decimal),
              stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f + stop_loss).round(round_decimal)
            }

            update_trade!(options)
            return true if queue_next_run
          end
        end

        false
      end

      # 1 Trade & 0 Orders.
      # Wait for trade to close.
      def step_2
        return false if oanda_active_trades.size == 0 && step_to(1) && queue_next_run
        return false if close_orders_after_exit_time && reset_steps
        false
      end

      # # 0 Trades & 0 Orders.
      # # Wait until day is over and start looking for trades again the next day.
      # def step_3
      #   return false if oanda_active_trades.size == 1 && step_to(2) && queue_next_run
      #   false
      # end

      private

      def enter_long?
        fast_exponential_moving_averages[-1] > slow_exponential_moving_averages[-1] &&
        fast_exponential_moving_averages[-2] <= slow_exponential_moving_averages[-2]
      end

      def enter_short?
        fast_exponential_moving_averages[-1] < slow_exponential_moving_averages[-1] &&
        fast_exponential_moving_averages[-2] >= slow_exponential_moving_averages[-2]
      end

      def take_profit_pips
        @take_profit_pips ||= ((ichimoku_cloud.senkou_span_a - ichimoku_cloud.senkou_span_b).abs / pip_size * take_profit_increment).floor
      end

      def close_orders_after_exit_time
        time_outside?('04:01', '21:00', 'utc+2') && exit_position!
      end

      def trade_options
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
      end
    end
  end
end
