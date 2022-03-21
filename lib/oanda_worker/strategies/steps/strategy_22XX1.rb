# Strategy22XX1
#
# To exit a trade:
#
#   Uses a stop loss order and take profit order on the trade which immediately gets replaced by opposite side orders to exit the trade.
#
module Strategies
  module Steps
    module Strategy22XX1
      # 0 Trades, 0 Orders.
      # Wait for a buy or sell signal.
      # Create trade with take profit and stop loss.
      def step_1
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(2) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        raise OandaWorker::StrategyStepError, "More than 2 active orders! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 2

        candles(smooth: true, include_incomplete_candles: false)
        trade_options

        if enter_long?
          @take_profit = take_profit_pips * pip_size
          @stop_loss   = take_profit_pips * stop_loss_factor * pip_size

          if create_long_order!
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
          @take_profit = take_profit_pips * pip_size
          @stop_loss   = take_profit_pips * stop_loss_factor * pip_size

          if create_short_order!
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

      # 1 Trade, 0 Orders.
      # Replace stop loss order with a mid price exit order.
      def step_2
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        raise OandaWorker::StrategyStepError, "More than 2 active orders! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 2

        order_options

        if oanda_long_trades.any?
          trade = oanda_long_trades.last
          create_short_order_as_stop_loss!(trade)
          return exit_stop_loss_order!(trade) && queue_next_run
        end

        if oanda_short_trades.any?
          trade = oanda_short_trades.last
          create_long_order_as_stop_loss!(trade)
          return exit_stop_loss_order!(trade) && queue_next_run
        end

        false
      end

      # 1 Trade, 1 Order.
      # Replace take profit order with a mid price exit order.
      def step_3
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        raise OandaWorker::StrategyStepError, "More than 2 active orders! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 2

        order_options

        if oanda_long_trades.any?
          trade = oanda_long_trades.last
          create_short_order_as_take_profit!(trade)
          return exit_take_profit_order!(trade) && queue_next_run
        end

        if oanda_short_trades.any?
          trade = oanda_short_trades.last
          create_long_order_as_take_profit!(trade)
          return exit_take_profit_order!(trade) && queue_next_run
        end

        false
      end

      # 1 Trade, 2 Orders.
      # Wait for trade to take profit or stop loss with exit orders.
      def step_4
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        raise OandaWorker::StrategyStepError, "More than 2 active orders! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 2

        false
      end

      # 0 Trades, 1 Order.
      # Exit last exit order and reset steps.
      def step_5
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        raise OandaWorker::StrategyStepError, "More than 2 active orders! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 2

        return false if exit_trades_and_orders! && reset_steps && queue_next_run
        false
      end

      private

      def enter_long?
        conditions = 0

        if exhaustion_moving_average_1.top_shadow_sizes[-1] < (exhaustion_moving_average_1.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_1.bottom_shadow_sizes[-1] > (exhaustion_moving_average_1.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.top_shadow_sizes[-1] < (exhaustion_moving_average_2.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_2.bottom_shadow_sizes[-1] > (exhaustion_moving_average_2.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.top_shadow_sizes[-1] < (exhaustion_moving_average_3.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_3.bottom_shadow_sizes[-1] > (exhaustion_moving_average_3.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        return false if conditions == 0

        if exhaustion_moving_average_1.top_shadow_sizes[-2] < (exhaustion_moving_average_1.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_1.bottom_shadow_sizes[-2] > (exhaustion_moving_average_1.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.top_shadow_sizes[-2] < (exhaustion_moving_average_2.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_2.bottom_shadow_sizes[-2] > (exhaustion_moving_average_2.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.top_shadow_sizes[-2] < (exhaustion_moving_average_3.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_3.bottom_shadow_sizes[-2] > (exhaustion_moving_average_3.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        false
      end

      def enter_short?
        conditions = 0

        if exhaustion_moving_average_1.bottom_shadow_sizes[-1] < (exhaustion_moving_average_1.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_1.top_shadow_sizes[-1] > (exhaustion_moving_average_1.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.bottom_shadow_sizes[-1] < (exhaustion_moving_average_2.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_2.top_shadow_sizes[-1] > (exhaustion_moving_average_2.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.bottom_shadow_sizes[-1] < (exhaustion_moving_average_3.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_3.top_shadow_sizes[-1] > (exhaustion_moving_average_3.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        return false if conditions == 0

        if exhaustion_moving_average_1.bottom_shadow_sizes[-2] < (exhaustion_moving_average_1.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_1.top_shadow_sizes[-2] > (exhaustion_moving_average_1.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.bottom_shadow_sizes[-2] < (exhaustion_moving_average_2.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_2.top_shadow_sizes[-2] > (exhaustion_moving_average_2.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.bottom_shadow_sizes[-2] < (exhaustion_moving_average_3.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_3.top_shadow_sizes[-2] > (exhaustion_moving_average_3.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        false
      end

      def create_long_order_as_stop_loss!(trade)
        order_options = {
          order_price: trade['stopLossOrder']['price'].to_f.round(round_decimal),
          units:       trade['initialUnits'].to_i.abs.to_s,
          tag:         tag_stop_loss
        }

        return create_order_at!('long', order_options)
      end

      def create_short_order_as_stop_loss!(trade)
        order_options = {
          order_price: trade['stopLossOrder']['price'].to_f.round(round_decimal),
          units:       trade['initialUnits'].to_i.abs.to_s,
          tag:         tag_stop_loss
        }

        return create_order_at!('short', order_options)
      end

      def create_long_order_as_take_profit!(trade)
        order_options = {
          order_price: trade['takeProfitOrder']['price'].to_f.round(round_decimal),
          units:       trade['initialUnits'].to_i.abs.to_s,
          tag:         tag_take_profit
        }

        return create_order_at!('long', order_options)
      end

      def create_short_order_as_take_profit!(trade)
        order_options = {
          order_price: trade['takeProfitOrder']['price'].to_f.round(round_decimal),
          units:       trade['initialUnits'].to_i.abs.to_s,
          tag:         tag_take_profit
        }

        return create_order_at!('short', order_options)
      end

      def exit_stop_loss_order!(trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
        exit_order!(trade['stopLossOrder'])
      end

      def exit_take_profit_order!(trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a take profit order!" unless trade['takeProfitOrder']
        exit_order!(trade['takeProfitOrder'])
      end

      def options
        @options
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

      def order_options
        @options = {
          'order' => {
            'instrument' => instrument,
            'timeInForce' => 'GTC',
            'type' => 'MARKET_IF_TOUCHED',
            'positionFill' => 'DEFAULT',
            'triggerCondition' => 'MID',
            'clientExtensions' => {
              'tag' => tag_order
            }
          }
        }
      end
    end
  end
end
