# Strategy61XX0
#
#   Martingale.
#   Roulette inspired strategy. Start with 1 unit, increment on each loss and reset with each win.
#   You will always be in the market.
#
# To enter a trade:
#
#   Orders placed at set pip interval sizes.
#   Long order above current close.
#   Short order below current close.
#
# To exit a trade:
#
#   Wait for take profit or stop loss to trigger.
#
module Strategies
  module Steps
    module Strategy61XX0
      # Initial Loop.

      # 0 Trades & 0 Orders.
      # Place long order with take profit and stop loss.
      def step_1
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(3) && queue_next_run

        order_options

        order_price       = current_channel_top_price
        stop_loss_price   = current_channel_top_price - channel_box_size_pips * pip_size
        take_profit_price = current_channel_top_price + channel_box_size_pips * pip_size

        order_options = {
          order_price:       order_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          units:             calculated_units_from_balance(config[:margin], :long) || config[:units],
          tag:               "#{tag_order}_1"
        }

        return false if create_long_order!(order_options) && step_to(2) && queue_next_run
        false
      end

      # 0 Trades & 1 Order.
      # Place short order with take profit and stop loss.
      def step_2
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(1) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(3) && queue_next_run

        order_options

        order_price       = current_channel_bottom_price
        stop_loss_price   = current_channel_bottom_price + channel_box_size_pips * pip_size
        take_profit_price = current_channel_bottom_price - channel_box_size_pips * pip_size

        order_options = {
          order_price:       order_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          units:             calculated_units_from_balance(config[:margin], :short) || config[:units],
          tag:               "#{tag_order}_2"
        }

        return false if create_short_order!(order_options) && step_to(3) && queue_next_run
        false
      end

      # 0 Trades & 2 Orders.
      # Wait for an order to trigger.
      def step_3
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(1) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(4) && queue_next_run
        false
      end

      # 1 Trade & 1 Order.
      # Cancel opposite order.
      def step_4
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(1) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(3) && queue_next_run
        return false if exit_orders! && step_to(5) && queue_next_run
        false
      end

      # Main Loop.
      # Reset steps when a spike caused a trade to take profit or stop loss, and also triggered the next order and it stopped out by take profit or stop loss as well.

      # 1 Trade & 0 Orders.
      # Create an incremented unit size opposite side order to open at current trade stop loss level.
      def step_5
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && exit_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(8) && queue_next_run

        order_options

        if oanda_long_trades.any?
          @options['order']['triggerCondition'] = 'BID'
          trade                                 = oanda_long_trades.last

          create_short_order_at_stop_loss_price!(trade)
          return false if step_to(6) && queue_next_run
        end

        if oanda_short_trades.any?
          @options['order']['triggerCondition'] = 'ASK'
          trade                                 = oanda_short_trades.last

          create_long_order_at_stop_loss_price!(trade)
          return false if step_to(6) && queue_next_run
        end

        false
      end

      # 1 Trade & 1 Order.
      # Create a 1 unit size same side order to open at current trade take profit level.
      def step_6
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && exit_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(8) && queue_next_run

        order_options

        if oanda_long_trades.any?
          @options['order']['triggerCondition'] = 'BID'
          trade                                 = oanda_long_trades.last

          create_long_order_at_take_profit_price!(trade)
          return false if step_to(7) && queue_next_run
        end

        if oanda_short_trades.any?
          @options['order']['triggerCondition'] = 'ASK'
          trade                                 = oanda_short_trades.last

          create_short_order_at_take_profit_price!(trade)
          return false if step_to(7) && queue_next_run
        end

        false
      end

      # 1 Trade & 2 Orders.
      # Wait for trade take profit or stop loss to trigger.
      def step_7
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && exit_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(8) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(9) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(5) && queue_next_run
        false
      end

      # 0 Trades & 2 Orders.
      # Wait for an order to trigger.
      def step_8
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && exit_orders! && reset_steps
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(9) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(5) && queue_next_run
        false
      end

      # 1 Trade & 1 Order.
      # Cancel remaining order.
      # Restart main loop.
      def step_9
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && exit_orders! && reset_steps
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && exit_orders! && step_to(5) && queue_next_run
        false
      end

      private

      def create_long_order_at_stop_loss_price!(trade)
        create_order_at_stop_loss_price!(:long, trade)
      end

      def create_short_order_at_stop_loss_price!(trade)
        create_order_at_stop_loss_price!(:short, trade)
      end

      def create_order_at_stop_loss_price!(type, trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']

        price         = trade['stopLossOrder']['price'].to_f
        current_units = trade['initialUnits'].to_i.abs
        units         = current_units * 2

        case type.to_sym
        when :long
          stop_loss_pips   = -channel_box_size_pips
          take_profit_pips = channel_box_size_pips
        when :short
          stop_loss_pips   = channel_box_size_pips
          take_profit_pips = -channel_box_size_pips
        end

        order_options = {
          order_price:      price.round(round_decimal),
          stop_loss_pips:   stop_loss_pips,
          take_profit_pips: take_profit_pips,
          units:            units.to_s
        }

        return create_order_at!(type.to_sym, order_options)
      end

      def create_long_order_at_take_profit_price!(trade)
        create_order_at_take_profit_price!(:long, trade)
      end

      def create_short_order_at_take_profit_price!(trade)
        create_order_at_take_profit_price!(:short, trade)
      end

      def create_order_at_take_profit_price!(type, trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a take profit order!" unless trade['takeProfitOrder']

        price = trade['takeProfitOrder']['price'].to_f

        case type.to_sym
        when :long
          units            = initial_units(:long)
          stop_loss_pips   = -channel_box_size_pips
          take_profit_pips = channel_box_size_pips
        when :short
          units            = initial_units(:short)
          stop_loss_pips   = channel_box_size_pips
          take_profit_pips = -channel_box_size_pips
        end

        order_options = {
          order_price:      price.round(round_decimal),
          stop_loss_pips:   stop_loss_pips,
          take_profit_pips: take_profit_pips,
          units:            units.to_s
        }

        return create_order_at!(type.to_sym, order_options)
      end

      # NOTE:
      #
      #   We work with integers because matching floating numbers to the current box prices is impossible.
      #   To accomplish this we simply devide the price by die pip size and then one more decimal.
      #
      #   (1.04593 / 0.0001)  => 10459.3
      #   (10459.3 / 0.1)     => 104593
      def current_close_integer_price
        @current_close_integer_price ||= (candles['candles'].last['mid']['c'].to_f / pip_size_increment).round
      end

      def current_channel_top_price
        current_channel_top_price = current_close_integer_price - (current_close_integer_price % channel_box_size_integer) + channel_box_size_integer
        (current_channel_top_price * pip_size_increment).round(round_decimal)
      end

      def current_channel_bottom_price
        current_channel_bottom_price = current_close_integer_price - (current_close_integer_price % channel_box_size_integer)
        (current_channel_bottom_price * pip_size_increment).round(round_decimal)
      end

      def pip_size_increment
        @pip_size_increment ||= pip_size * 0.1
      end

      def initial_units(type)
        calculated_units_from_balance(config[:margin], type) || config[:units]
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
    end
  end
end
