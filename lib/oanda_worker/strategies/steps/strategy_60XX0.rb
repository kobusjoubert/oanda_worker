# Strategy60XX0
#
# To enter a trade:
#
#   Only trade long when the channel_trend (all 3 channel trends) is up and vice versa.
#   Place 5 orders, 3 orders above the channel_middle_price, 1 on the channel_middle_price and 1 below the channel_middle_price.
#
# To exit a trade:
#
#   As soon as the channel_trend changes, close all orders and trades and place new orders.
#   Uses a stop loss order and take profit order on the trade to exit the trade.
#
module Strategies
  module Steps
    module Strategy60XX0
      # 0 Trades & 0 Orders.
      # Wait for a buy or sell signal.
      # Update previous_channel_trend to current trend.
      def step_1
        if create_long_orders?
          self.previous_channel_trend        = high_low_channel.channel_trend
          self.previous_channel_middle_price = high_low_channel.channel_middle_price
          self.previous_channel_top_price    = high_low_channel.channel_top_price
          self.previous_channel_bottom_price = high_low_channel.channel_bottom_price
          return false if step_to(2) && queue_next_run
        end

        if create_short_orders?
          self.previous_channel_trend        = high_low_channel.channel_trend
          self.previous_channel_middle_price = high_low_channel.channel_middle_price
          self.previous_channel_top_price    = high_low_channel.channel_top_price
          self.previous_channel_bottom_price = high_low_channel.channel_bottom_price
          return false if step_to(7) && queue_next_run
        end

        false
      end

      # Long Orders (step 2 to 6).

      # 0 Trades & 0 Orders.
      # Create order 1 with stop loss and take profit.
      def step_2
        order_options

        order_price       = high_low_channel.channel_top_price - 1 * order_price_fraction
        take_profit_price = high_low_channel.channel_top_price
        stop_loss_price   = high_low_channel.channel_top_price - 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_1"
        }

        return false if create_long_order!(order_options) && step_to(3) && queue_next_run
        false
      end

      # 0 Trades & 1 Orders.
      # Create order 2 with stop loss and take profit.
      def step_3
        order_options

        order_price       = high_low_channel.channel_top_price - 2 * order_price_fraction
        take_profit_price = high_low_channel.channel_top_price
        stop_loss_price   = high_low_channel.channel_top_price - 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_2"
        }

        return false if create_long_order!(order_options) && step_to(4) && queue_next_run
        false
      end

      # 0 Trades & 2 Orders.
      # Create order 3 with stop loss and take profit.
      def step_4
        order_options

        order_price       = high_low_channel.channel_top_price - 3 * order_price_fraction
        take_profit_price = high_low_channel.channel_top_price
        stop_loss_price   = high_low_channel.channel_top_price - 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_3"
        }

        return false if create_long_order!(order_options) && step_to(5) && queue_next_run
        false
      end

      # 0 Trades & 3 Orders.
      # Create order 4 with stop loss and take profit.
      def step_5
        order_options

        order_price       = high_low_channel.channel_top_price - 4 * order_price_fraction
        take_profit_price = high_low_channel.channel_top_price
        stop_loss_price   = high_low_channel.channel_top_price - 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_4"
        }

        return false if create_long_order!(order_options) && step_to(6) && queue_next_run
        false
      end

      # 0 Trades & 4 Orders.
      # Create order 5 with stop loss and take profit.
      def step_6
        order_options

        order_price       = high_low_channel.channel_top_price - 5 * order_price_fraction
        take_profit_price = high_low_channel.channel_top_price
        stop_loss_price   = high_low_channel.channel_top_price - 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_5"
        }

        return false if create_long_order!(order_options) && step_to(12) && queue_next_run
        false
      end

      # Short Orders (step 7 to 11).

      # 0 Trades & 0 Orders.
      # Create order 1 with stop loss and take profit.
      def step_7
        order_options

        order_price       = high_low_channel.channel_bottom_price + 1 * order_price_fraction
        take_profit_price = high_low_channel.channel_bottom_price
        stop_loss_price   = high_low_channel.channel_bottom_price + 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_1"
        }

        return false if create_short_order!(order_options) && step_to(8) && queue_next_run
        false
      end

      # 0 Trades & 1 Orders.
      # Create order 2 with stop loss and take profit.
      def step_8
        order_options

        order_price       = high_low_channel.channel_bottom_price + 2 * order_price_fraction
        take_profit_price = high_low_channel.channel_bottom_price
        stop_loss_price   = high_low_channel.channel_bottom_price + 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_2"
        }

        return false if create_short_order!(order_options) && step_to(9) && queue_next_run
        false
      end

      # 0 Trades & 2 Orders.
      # Create order 3 with stop loss and take profit.
      def step_9
        order_options

        order_price       = high_low_channel.channel_bottom_price + 3 * order_price_fraction
        take_profit_price = high_low_channel.channel_bottom_price
        stop_loss_price   = high_low_channel.channel_bottom_price + 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_3"
        }

        return false if create_short_order!(order_options) && step_to(10) && queue_next_run
        false
      end

      # 0 Trades & 3 Orders.
      # Create order 4 with stop loss and take profit.
      def step_10
        order_options

        order_price       = high_low_channel.channel_bottom_price + 4 * order_price_fraction
        take_profit_price = high_low_channel.channel_bottom_price
        stop_loss_price   = high_low_channel.channel_bottom_price + 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_4"
        }

        return false if create_short_order!(order_options) && step_to(11) && queue_next_run
        false
      end

      # 0 Trades & 4 Orders.
      # Create order 5 with stop loss and take profit.
      def step_11
        order_options

        order_price       = high_low_channel.channel_bottom_price + 5 * order_price_fraction
        take_profit_price = high_low_channel.channel_bottom_price
        stop_loss_price   = high_low_channel.channel_bottom_price + 6 * order_price_fraction

        order_options = {
          order_price:       order_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          tag:               "#{tag_order}_5"
        }

        return false if create_short_order!(order_options) && step_to(12) && queue_next_run
        false
      end

      # All orders placed!

      # 0 Trades & 5 Orders.
      # Wait for orders to trigger.
      def step_12
        return false if oanda_active_trades.any? && step_to(13) && queue_next_run
        return false if channel_middle_price_changed? && step_to(15) && queue_next_run
        return false if high_low_channel.channel_trend == 'up' && channel_top_price_changed? && step_to(15) && queue_next_run
        return false if high_low_channel.channel_trend == 'down' && channel_bottom_price_changed? && step_to(15) && queue_next_run
        false
      end

      # > 0 Trades & < 5 Orders.
      # Wait for trades to take profit or stop loss, all trades will close at once as the take profit and stop loss values are the same for all trades.
      # Wait for channel_trend to change.
      # Wait for channel_middle_price to change.
      def step_13
        return false if oanda_active_trades.empty? && exit_trades_and_orders! && reset_steps
        return false if channel_trend_changed? && step_to(14) && queue_next_run
        false
      end

      # > 0 Trades & < 5 Orders.
      # The channel_trend changed.
      # Update previous_channel_trend to current trend.
      # Close open orders and positions.
      # Place new orders.
      def step_14
        self.previous_channel_trend = high_low_channel.channel_trend
        return false if exit_trades_and_orders! && reset_steps
        false
      end

      # > 0 Trades & < 5 Orders.
      # The channel_middle_price changed.
      # Update previous_channel_middle_price to current channel_middle_price.
      # Update orders with new prices, take profits and stop losses.
      # Update stop loss values on all open trades. (Net yet implemented!)
      def step_15
        self.previous_channel_middle_price = high_low_channel.channel_middle_price
        self.previous_channel_top_price    = high_low_channel.channel_top_price
        self.previous_channel_bottom_price = high_low_channel.channel_bottom_price
        return false if exit_trades_and_orders! && reset_steps
        false
      end

      private

      def order_options
        @options = {
          'order' => {
            'instrument' => instrument,
            'timeInForce' => 'GTC',
            'type' => 'MARKET_IF_TOUCHED',
            'positionFill' => 'DEFAULT',
            'triggerCondition' => 'MID',
            'clientExtensions' => {
              'tag' => "#{tag_order}_#{step}" # Replaced in each step.
            }
          }
        }
      end

      def order_price_fraction
        @order_price_fraction ||= begin
          value = 0

          if high_low_channel.channel_trend == 'up'
            value = ((high_low_channel.channel_top_price - high_low_channel.channel_middle_price).abs / 4).round(round_decimal)
          end

          if high_low_channel.channel_trend == 'down'
            value = ((high_low_channel.channel_bottom_price - high_low_channel.channel_middle_price).abs / 4).round(round_decimal)
          end

          value
        end
      end

      def previous_channel_trend
        $redis.get("#{key_base}:previous_channel_trend") || 'down'
      end

      def previous_channel_trend=(value)
        $redis.set("#{key_base}:previous_channel_trend", value.to_s)
      end

      def previous_channel_middle_price
        $redis.get("#{key_base}:previous_channel_middle_price") && $redis.get("#{key_base}:previous_channel_middle_price").to_f
      end

      def previous_channel_middle_price=(value)
        $redis.set("#{key_base}:previous_channel_middle_price", value.to_s)
      end

      def previous_channel_top_price
        $redis.get("#{key_base}:previous_channel_top_price") && $redis.get("#{key_base}:previous_channel_top_price").to_f
      end

      def previous_channel_top_price=(value)
        $redis.set("#{key_base}:previous_channel_top_price", value.to_s)
      end

      def previous_channel_bottom_price
        $redis.get("#{key_base}:previous_channel_bottom_price") && $redis.get("#{key_base}:previous_channel_bottom_price").to_f
      end

      def previous_channel_bottom_price=(value)
        $redis.set("#{key_base}:previous_channel_bottom_price", value.to_s)
      end

      def channel_trend_changed?
        previous_channel_trend != high_low_channel.channel_trend
      end

      def channel_middle_price_changed?
        previous_channel_middle_price != high_low_channel.channel_middle_price
      end

      def channel_top_price_changed?
        previous_channel_top_price != high_low_channel.channel_top_price
      end

      def channel_bottom_price_changed?
        previous_channel_bottom_price != high_low_channel.channel_bottom_price
      end

      def create_long_orders?
        high_low_channel.channel_trend == 'up'
      end

      def create_short_orders?
        high_low_channel.channel_trend == 'down'
      end
    end
  end
end
