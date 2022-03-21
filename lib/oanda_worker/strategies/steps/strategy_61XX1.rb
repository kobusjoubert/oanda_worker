# Strategy61XX1
#
#   Martingale lagging.
#   Roulette inspired strategy. Start with 1 unit, increment on each loss and reset with each win.
#   You will always be in the market. Reverse orders used as stop losses.
#
# To enter a trade:
#
#   Orders placed at set pip interval sizes.
#   Long order above current close.
#   Short order below current close.
#
# To exit a trade:
#
#   Wait for stop loss to trigger.
#
module Strategies
  module Steps
    module Strategy61XX1
      # Initial Loop.

      # 0 Trades & 0 Orders.
      # Place long order with stop loss.
      def step_1
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(3) && queue_next_run

        order_options

        order_price     = current_channel_top_price
        stop_loss_price = current_channel_top_price - channel_box_size_pips * pip_size

        order_options = {
          order_price:     order_price.round(round_decimal),
          stop_loss_price: stop_loss_price.round(round_decimal),
          units:           calculated_units_from_balance(config[:margin], :long) || config[:units],
          tag:             "#{tag_order}_1"
        }

        return false if create_long_order!(order_options) && step_to(2) && queue_next_run
        false
      end

      # 0 Trades & 1 Order.
      # Place short order with stop loss.
      def step_2
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(1) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(3) && queue_next_run

        order_options

        order_price     = current_channel_bottom_price
        stop_loss_price = current_channel_bottom_price + channel_box_size_pips * pip_size

        order_options = {
          order_price:     order_price.round(round_decimal),
          stop_loss_price: stop_loss_price.round(round_decimal),
          units:           calculated_units_from_balance(config[:margin], :short) || config[:units],
          tag:             "#{tag_order}_2"
        }

        return false if create_short_order!(order_options) && step_to(3) && queue_next_run
        false
      end

      # 0 Trades & 2 Orders.
      # Wait for an order to trigger.
      def step_3
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(1) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(4) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        false
      end

      # 1 Trade & 1 Order.
      # Cancel opposite order.
      def step_4
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(1) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 2 && step_to(3) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        return false if exit_orders! && step_to(5) && queue_next_run
        false
      end

      # Main Loop.

      # 1 Trade & 0 Orders.
      # Replace trade's stop loss with an incremented unit size opposite side order (stop loss) & stop loss.
      # Got to step 6.
      def step_5
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps

        order_options

        if oanda_long_trades.any?
          trade = oanda_long_trades.last
          create_short_order_as_stop_loss!(:new, trade)
          return false if exit_stop_loss_order!(trade) && step_to(6) && queue_next_run
        end

        if oanda_short_trades.any?
          trade = oanda_short_trades.last
          create_long_order_as_stop_loss!(:new, trade)
          return false if exit_stop_loss_order!(trade) && step_to(6) && queue_next_run
        end

        false
      end

      # 1 Trade & 1 Order.
      # When opposite side order (stop loss) has been triggered, go to step 5.
      # When new channel level has been reached, go to step 7.
      def step_6
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size > 0 && oanda_active_orders.size == 0 && step_to(5) && queue_next_run
        return false if new_channel_level_reached? && safe_to_update_stop_loss_order? && step_to(7) && queue_next_run
        false
      end

      # 1 Trade & 1 Order.
      # Create new opposite side order (stop loss) with new price and units to only have 1 unit left when triggered.
      # Remove old opposite side order (stop loss).
      # Go to step 6.
      #
      # NOTE: Don't queue_next_run after step_to(6)! In backtesting candle high low could span over channel level and queueing next run would cause an endless loop between step 6 and 7!
      def step_7
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size > 0 && oanda_active_orders.size == 0 && step_to(5) && queue_next_run
        return false if !safe_to_update_stop_loss_order? && step_to(6) && queue_next_run

        order_options

        if oanda_long_trades.any?
          trade = oanda_long_trades.last
          order = oanda_short_orders.last
          create_short_order_as_stop_loss!(:existing, trade, order)
          return false if exit_order!(order) && step_to(6)
        end

        if oanda_short_trades.any?
          trade = oanda_short_trades.last
          order = oanda_long_orders.last
          create_long_order_as_stop_loss!(:existing, trade, order)
          return false if exit_order!(order) && step_to(6)
        end

        false
      end

      # # 1 Trade & 2 Order.
      # # Remove old opposite side order (stop loss).
      # # Go to step 6.
      # #
      # # NOTE: This step has been placed inside step_7 because of backtesting issues which sometimes triggers the new order before we can cancel the old order.
      # def step_8
      #   return false if oanda_active_trades.size > 0 && oanda_active_orders.size == 0 && step_to(5) && queue_next_run
      #
      #   if oanda_long_trades.any?
      #     order = oanda_short_orders.last
      #     return false if exit_order!(order) && step_to(6) && queue_next_run
      #   end
      #
      #   if oanda_short_trades.any?
      #     order = oanda_long_orders.last
      #     return false if exit_order!(order) && step_to(6) && queue_next_run
      #   end
      #
      #   false
      # end

      private

      def new_channel_level_reached?
        current_candle = candles(include_incomplete_candles: true, refresh: false)['candles'].last['mid']
        bottom, top    = current_candle['l'].to_f, current_candle['h'].to_f
        bottom, top    = top, bottom if bottom > top

        if oanda_long_trades.any?
          new_channel_level = oanda_short_orders.last['price'].to_f + channel_box_size_pips * pip_size * 2

          if backtesting?
            return bottom > new_channel_level ? true : false
          else
            return top > new_channel_level ? true : false
          end
        end

        if oanda_short_trades.any?
          new_channel_level = oanda_long_orders.last['price'].to_f - channel_box_size_pips * pip_size * 2

          if backtesting?
            return top < new_channel_level ? true : false
          else
            return bottom < new_channel_level ? true : false
          end
        end

        false
      end

      def safe_to_update_stop_loss_order?
        current_close = close(include_incomplete_candles: true, refresh: false)

        if oanda_long_trades.any?
          order           = oanda_short_orders.last
          price_increment = price_increment(current_close, order)
          price           = order['price'].to_f + channel_box_size_pips * pip_size * price_increment
          return price < current_close ? true : false
        end

        if oanda_short_trades.any?
          order           = oanda_long_orders.last
          price_increment = price_increment(current_close, order)
          price           = order['price'].to_f - channel_box_size_pips * pip_size * price_increment
          return price > current_close ? true : false
        end

        false
      end

      def create_long_order_as_stop_loss!(new_or_existing, trade, order = nil)
        stop_loss_pips = -channel_box_size_pips
        current_units  = trade['initialUnits'].to_i.abs

        case new_or_existing.to_sym
        when :new
          raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
          price           = trade['stopLossOrder']['price'].to_f
          units           = current_units + current_units * 2
        when :existing
          current_close   = close(include_incomplete_candles: true, refresh: false)
          price_increment = price_increment(current_close, order)
          price           = order['price'].to_f - channel_box_size_pips * pip_size * price_increment
          units           = current_units + initial_units(:long)
          backtest_logging("old sl order price: #{order['price']}, new sl order price: #{price}")
        end

        order_options = {
          order_price:    price.round(round_decimal),
          stop_loss_pips: stop_loss_pips,
          units:          units.to_s,
          tag:            tag_stop_loss
        }

        return create_long_order!(order_options)
      end

      def create_short_order_as_stop_loss!(new_or_existing, trade, order = nil)
        stop_loss_pips = channel_box_size_pips
        current_units  = trade['initialUnits'].to_i.abs

        case new_or_existing.to_sym
        when :new
          raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
          price           = trade['stopLossOrder']['price'].to_f
          units           = current_units + current_units * 2
        when :existing
          current_close   = close(include_incomplete_candles: true, refresh: false)
          price_increment = price_increment(current_close, order)
          price           = order['price'].to_f + channel_box_size_pips * pip_size * price_increment
          units           = current_units + initial_units(:short)
          backtest_logging("old sl order price: #{order['price']}, new sl order price: #{price}")
        end

        order_options = {
          order_price:    price.round(round_decimal),
          stop_loss_pips: stop_loss_pips,
          units:          units.to_s,
          tag:            tag_stop_loss
        }

        return create_short_order!(order_options)
      end

      def exit_stop_loss_order!(trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
        exit_order!(trade['stopLossOrder'])
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

      def price_increment(close, order)
        price_increment = ((close - order['price'].to_f).abs / (channel_box_size_pips * pip_size)).floor - 1
        raise OandaWorker::StrategyStepError, "Price increment too small! close: #{close}, current order price: #{order['price']}" if price_increment < 1
        price_increment
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
