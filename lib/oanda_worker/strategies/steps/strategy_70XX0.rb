# Strategy70XX0
#
#   Retirement.
#   SPAM like strategy with incremented unit size orders.
#   Agimat indicator yellow arrow to determine entry.
#
# To enter a trade:
#
#   Trade open when support or resistance level reached.
#   Long trade when support level reached.
#   Short trade when resistance level reached.
#
# To exit a trade:
#
#   Wait for take profit to trigger.
#
module Strategies
  module Steps
    module Strategy70XX0
      # Initial Loop.

      # 0 Trades & 0 Orders.
      # Wait for indicator to signal trade entry and enter trade with take profit.
      def step_1
        trade_options

        if enter_long?
          backtest_logging("risk_factor: #{fractal.risk_factor}")

          if create_order_at!(:long)
            take_profit = take_profit_pips * pip_size
            # stop_loss   = stop_loss_pips * max_trades * pip_size

            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f + take_profit).round(round_decimal),
              # stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f - stop_loss).round(round_decimal)
            }

            return false if update_trade!(options) && step_to(4) && queue_next_run
          end
        end

        if enter_short?
          backtest_logging("risk_factor: #{fractal.risk_factor}")

          if create_order_at!(:short)
            take_profit = take_profit_pips * pip_size
            # stop_loss   = stop_loss_pips * max_trades * pip_size

            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f - take_profit).round(round_decimal),
              # stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f + stop_loss).round(round_decimal)
            }

            return false if update_trade!(options) && step_to(4) && queue_next_run
          end
        end

        false
      end

      # Main Loop.

      # 1+ Trades & 1 Order.
      # Wait for order to trigger.
      def step_2
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps
        return false if oanda_active_orders.size == 0 && step_to(3) && queue_next_run
        false
      end

      # 1+ Trades & 0 Order.
      # Update take profit prices on all trades to match the latest trade's take profit price.
      def step_3
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps

        if oanda_long_trades.any?
          new_take_profit_price = oanda_long_trades.map{ |trade| trade['takeProfitOrder']['price'].to_f }.min

          oanda_long_trades.each do |trade|
            next if trade['takeProfitOrder']['price'].to_f == new_take_profit_price

            options = {
              id:          trade['id'],
              take_profit: (new_take_profit_price).round(round_decimal)
            }

            update_trade!(options)
          end

          return false if step_to(4) && queue_next_run
        end

        if oanda_short_trades.any?
          new_take_profit_price = oanda_short_trades.map{ |trade| trade['takeProfitOrder']['price'].to_f }.max

          oanda_short_trades.each do |trade|
            next if trade['takeProfitOrder']['price'].to_f == new_take_profit_price

            options = {
              id:          trade['id'],
              take_profit: (new_take_profit_price).round(round_decimal)
            }

            update_trade!(options)
          end

          return false if step_to(4) && queue_next_run
        end

        false
      end

      # 1+ Trades & 0 Order.
      # Place order at new channel level with take profit.
      # Restart main loop.
      def step_4
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps
        return false if oanda_active_trades.size >= max_trades && step_to(5)

        order_options

        if oanda_long_trades.any?
          order_price   = oanda_long_trades.map{ |trade| trade['price'].to_f }.min - channel_box_size_pips * pip_size
          initial_units = oanda_long_trades.map{ |trade| trade['initialUnits'].to_i }.min.abs
          # stop_loss     = stop_loss_pips * (max_trades - oanda_long_trades.size)
          total_loss    = 0

          oanda_long_trades.each do |trade|
            trade_take_profit_pips = (trade['takeProfitOrder']['price'].to_f - trade['price'].to_f).round(round_decimal) / pip_size
            trade_take_profit_pips = trade_take_profit_pips - take_profit_pips
            total_loss             += trade['initialUnits'].to_i.abs * trade_take_profit_pips
          end

          order_units = (initial_units * (oanda_long_trades.size + 1) - (total_loss / take_profit_pips)).floor

          order_options = {
            order_price:      order_price.round(round_decimal),
            units:            order_units,
            take_profit_pips: +take_profit_pips,
            # stop_loss_pips:   -stop_loss
          }

          return false if create_order_at!(:long, order_options) && step_to(2)
        end

        if oanda_short_trades.any? 
          order_price   = oanda_short_trades.map{ |trade| trade['price'].to_f }.max + channel_box_size_pips * pip_size
          initial_units = oanda_short_trades.map{ |trade| trade['initialUnits'].to_i }.max.abs
          # stop_loss     = stop_loss_pips * (max_trades - oanda_short_trades.size)
          total_loss    = 0

          oanda_short_trades.each do |trade|
            trade_take_profit_pips = (trade['takeProfitOrder']['price'].to_f - trade['price'].to_f).round(round_decimal) / pip_size
            trade_take_profit_pips = trade_take_profit_pips + take_profit_pips
            total_loss             -= trade['initialUnits'].to_i.abs * trade_take_profit_pips
          end

          order_units = (initial_units * (oanda_short_trades.size + 1) - (total_loss / take_profit_pips)).floor

          order_options = {
            order_price:      order_price.round(round_decimal),
            units:            order_units,
            take_profit_pips: -take_profit_pips,
            # stop_loss_pips:   +stop_loss
          }

          return false if create_order_at!(:short, order_options) && step_to(2)
        end

        false
      end

      # 5 Trades & 0 Orders.
      # Wait for trades to take profit or stop loss when max trades reached and restart initial loop.
      def step_5
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps
        false
      end

      private

      def enter_long?
        fractal.possible_down?
      end

      def enter_short?
        fractal.possible_up?
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
            'triggerCondition' => 'DEFAULT',
            'clientExtensions' => {
              'tag' => "#{tag_order}_#{step}"
            }
          }
        }
      end

      def cleanup
        true
      end
    end
  end
end
