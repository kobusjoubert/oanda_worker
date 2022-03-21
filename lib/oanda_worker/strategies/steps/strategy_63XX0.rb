# Strategy63XX0
#
#   Channel Corrections.
#   Wait for high low channel to break.
#   Place correction orders according to channel percentage.
#
# To enter a trade:
#
#   Market must break out of high low channel.
#   Long order when breaking out below.
#   Short order when breaking out above.
#
# To exit a trade:
#
#   Wait for take profit to trigger.
#
module Strategies
  module Steps
    module Strategy63XX0
      # Initial Loop.

      # 0 Trades & 0 Orders.
      # Wait for channel breakout.
      def step_1
        return false if create_orders? && step_to(2) && queue_next_run
        false
      end

      # 0 Trades & 0 Orders.
      # Place orders.
      def step_2
        if create_orders?
          order_options

          order_channel_size = (simple_high_low_channel.channel_size * order_channel_percentage).round(round_decimal)
          take_profit_size   = (simple_high_low_channel.channel_size * take_profit_percentage).round(round_decimal)
          j                  = 0
        end

        if create_long_orders?
          max_orders.times do |i|
            order_price       = simple_high_low_channel.lowest_low - ((i + 1) * order_channel_size)
            next if order_price >= current_candle['mid']['c'].to_f

            take_profit_price = order_price + take_profit_size
            untis             = (initial_units(:long) * order_size_increment**j).floor

            j += 1

            order_options = {
              order_price:       order_price.round(round_decimal),
              take_profit_price: take_profit_price.round(round_decimal),
              units:             untis,
              tag:               "#{tag_order}_#{i + 1}"
            }

            create_long_order!(order_options)
          end

          backtest_logging("channel_size: #{simple_high_low_channel.channel_size.round(round_decimal)}, highest_high: #{simple_high_low_channel.highest_high.round(round_decimal)}, lowest_low: #{simple_high_low_channel.lowest_low.round(round_decimal)}, channel_top_price: #{simple_high_low_channel.channel_top_price.round(round_decimal)}, channel_bottom_price: #{simple_high_low_channel.channel_bottom_price.round(round_decimal)}")
          simple_high_low_channel.update_channel_prices!
          return false if step_to(3) # && queue_next_run
        end

        if create_short_orders?
          max_orders.times do |i|
            order_price       = simple_high_low_channel.highest_high + ((i + 1) * order_channel_size)
            next if order_price <= current_candle['mid']['c'].to_f

            take_profit_price = order_price - take_profit_size
            untis             = (initial_units(:short) * order_size_increment**j).floor

            j += 1

            order_options = {
              order_price:       order_price.round(round_decimal),
              take_profit_price: take_profit_price.round(round_decimal),
              units:             untis,
              tag:               "#{tag_order}_#{i + 1}"
            }

            create_short_order!(order_options)
          end

          backtest_logging("channel_size: #{simple_high_low_channel.channel_size.round(round_decimal)}, highest_high: #{simple_high_low_channel.highest_high.round(round_decimal)}, lowest_low: #{simple_high_low_channel.lowest_low.round(round_decimal)}, channel_top_price: #{simple_high_low_channel.channel_top_price.round(round_decimal)}, channel_bottom_price: #{simple_high_low_channel.channel_bottom_price.round(round_decimal)}")
          simple_high_low_channel.update_channel_prices!
          return false if step_to(3) # && queue_next_run
        end

        false
      end

      # 0 Trades & 1+ Orders.
      # Wait for channel direction to reverse and step to 4.
      # Wait for order to trigger and step to 5.
      def step_3
        simple_high_low_channel.update_channel_prices! if create_orders?
        return false if oanda_long_orders.any? && create_short_orders? && step_to(4) && queue_next_run
        return false if oanda_short_orders.any? && create_long_orders? && step_to(4) && queue_next_run
        return false if oanda_active_trades.any? && initialize_active_trades && step_to(5) && queue_next_run
        false
      end

      # 0 Trades & 1+ Orders.
      # Cancel current orders and step to 2.
      def step_4
        return false if exit_trades_and_orders! && cleanup && step_to(2) && queue_next_run
        false
      end

      # Main Loop.

      # 1+ Trades & 1+ Orders.
      # Update take profit prices on all trades to match the latest trade's take profit price and step to 6.
      def step_5
        return false if oanda_active_trades.size == 0 && exit_orders! && cleanup && reset_steps

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

          return false if step_to(6) && queue_next_run
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

          return false if step_to(6) && queue_next_run
        end

        false
      end

      # 1+ Trades & 1+ Orders.
      # Wait for new orders to trigger and step to 5.
      def step_6
        return false if oanda_active_trades.size == 0 && exit_orders! && cleanup && reset_steps

        if active_trades != oanda_active_trades.size
          return false if increment_active_trades && step_to(5) && queue_next_run
        end

        false
      end

      private

      def create_long_orders?
        @create_long_orders ||= simple_high_low_channel.channel_bottom_breakout?
      end

      def create_short_orders?
        @create_short_orders ||= simple_high_low_channel.channel_top_breakout?
      end

      def create_orders?
        create_long_orders? || create_short_orders?
      end

      def initialize_active_trades
        self.active_trades = 1
      end

      def increment_active_trades
        current_active_trades = active_trades
        self.active_trades    = current_active_trades + 1
      end

      def active_trades
        $redis.get("#{key_base}:active_trades") && $redis.get("#{key_base}:active_trades").to_i
      end

      def active_trades=(value)
        $redis.set("#{key_base}:active_trades", value.to_i)
      end

      def initial_units(type)
        redis_initial_units = $redis.get("#{key_base}:initial_units")
        return redis_initial_units.to_i if redis_initial_units

        units = ((calculated_units_from_balance(config[:margin], type) || config[:units]) * initial_units_adjustment_factor).floor
        $redis.set("#{key_base}:initial_units", units)
        units.to_i
      end

      def initial_units_adjustment_factor
        @initial_units_adjustment_factor ||= initial_units_channel_base.to_f / simple_high_low_channel.channel_size.to_f
      end

      def calculated_units_from_balance(margin = nil, type)
        return nil unless margin
        margin         = margin.to_f
        trigger_price  = TRIGGER_CONDITION['MID']
        oanda_account  = oanda_client.account(account).summary.show
        balance        = oanda_account['account']['balance'].to_f
        leverage       = oanda_account['account']['marginRate'].to_f # 0.01 = 100:1, 0.02 = 50:1, 1 = 1:1
        current_candle = candles(include_incomplete_candles: true, refresh: false, price: 'MAB')['candles'].last
        units          = balance / current_candle[trigger_price[type]]['c'].to_f / leverage
        units          = units * margin / 100
        units.floor
      end

      def cleanup
        super
        $redis.del("#{key_base}:initial_units")
        $redis.del("#{key_base}:active_trades")
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
              'tag' => "#{tag_order}_#{step}"
            }
          }
        }
      end
    end
  end
end
