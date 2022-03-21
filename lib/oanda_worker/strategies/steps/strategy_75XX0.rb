# Strategy75XX0
#
#   Retirement.
#   SPAM like strategy with incremented unit size orders.
#   Agimat indicator yellow arrow to determine entry and point and figure.
#   Automatic take profit adjustment according to market volatility.
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
    module Strategy75XX0
      # Initial Loop.

      # 0 Trades & 0 Orders.
      # Wait for indicator to signal trade entry and enter trade with take profit.
      def step_1
        trade_options

        trades_units_reset if use_stop_losses && (enter_long? || enter_short?)

        if enter_long?
          units = ((calculated_units_from_balance(config[:margin], :long) || config[:units]) * initial_units_adjustment_factor).floor

          if create_order_at!(:long, units: units)
            trades_units_push(oanda_order['orderFillTransaction']['units'].to_i) if use_stop_losses
            self.initial_units = oanda_order['orderFillTransaction']['units'].to_i
            self.trades_opened = 1

            take_profit = take_profit_pips * pip_size
            stop_loss   = stop_loss_pips * pip_size if use_stop_losses

            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f + take_profit).round(round_decimal)
            }

            options.merge!(stop_loss: (oanda_order['orderFillTransaction']['price'].to_f - stop_loss).round(round_decimal)) if use_stop_losses
            return false if update_trade!(options) && step_to(4) && queue_next_run
          end
        end

        if enter_short?
          units = ((calculated_units_from_balance(config[:margin], :short) || config[:units]) * initial_units_adjustment_factor).floor

          if create_order_at!(:short, units: units)
            trades_units_push(oanda_order['orderFillTransaction']['units'].to_i) if use_stop_losses
            self.initial_units = oanda_order['orderFillTransaction']['units'].to_i
            self.trades_opened = 1

            take_profit = take_profit_pips * pip_size
            stop_loss   = stop_loss_pips * pip_size if use_stop_losses

            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f - take_profit).round(round_decimal)
            }

            options.merge!(stop_loss: (oanda_order['orderFillTransaction']['price'].to_f + stop_loss).round(round_decimal)) if use_stop_losses
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
        return false if oanda_active_orders.size == 0 && increment_trades_opened && step_to(3) && queue_next_run
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
      # Place order at new channel level with take profit and stop loss.
      # Restart main loop.
      def step_4
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps
        return false if trades_opened >= max_trades && step_to(5)

        order_options

        trades_closed     = trades_opened - oanda_active_trades.size
        trades_closed     = 0 if trades_closed < 0
        profit_loss_units = 0

        backtest_logging("trades_opened: #{trades_opened}, trades_closed: #{trades_closed}, channel_box_size_pips: #{channel_box_size_pips}, take_profit_pips: #{take_profit_pips.round(1)}, max_xo_length: #{max_xo_length}, from_date: #{indicator_pf_a['data'].first['attributes']['candle_at'].split('T')[0]}")

        if oanda_long_trades.any?
          # Determine new order price.
          order_price = oanda_long_trades.map{ |trade| trade['price'].to_f }.min - channel_box_size_pips * pip_size

          # Loop over current active trades and sum projected profit loss at the time the new order will trigger.
          # Uses the current trade full spread as a best guess as to what the remaining half spread will be when the trade closes.
          oanda_long_trades.each do |trade|
            full_spread_pips        = current_candle_full_spread / pip_size
            trade_take_profit_pips  = ((trade['takeProfitOrder']['price'].to_f - trade['price'].to_f).round(round_decimal) / pip_size) - channel_box_size_pips
            trade_take_profit_units = (trade['initialUnits'].to_i.abs / take_profit_pips * (trade_take_profit_pips - full_spread_pips)).round
            profit_loss_units       += trade_take_profit_units
          end

          # Loop over trades closed and sum projected profit loss at the time the new order will trigger.
          if use_stop_losses
            trades_closed.times do |i|
              profit_loss_units -= (trades_units[i] / take_profit_pips.to_f * stop_loss_pips.to_f).ceil
            end
          end

          # Determine new order units.
          order_units = (initial_units * (trades_opened + 1) - profit_loss_units).floor
          trades_units_push(order_units) if use_stop_losses

          order_options = {
            order_price:      order_price.round(round_decimal),
            units:            order_units,
            take_profit_pips: +take_profit_pips
          }

          order_options.merge!(stop_loss_pips: -stop_loss_pips) if use_stop_losses
          return false if create_order_at!(:long, order_options) && step_to(2)
        end

        if oanda_short_trades.any? 
          # Determine new order price.
          order_price = oanda_short_trades.map{ |trade| trade['price'].to_f }.max + channel_box_size_pips * pip_size

          # Loop over current active trades and sum projected profit loss at the time the new order will trigger.
          # Uses the current trade full spread as a best guess as to what the remaining half spread will be when the trade closes.
          oanda_short_trades.each do |trade|
            full_spread_pips        = current_candle_full_spread / pip_size
            trade_take_profit_pips  = ((trade['takeProfitOrder']['price'].to_f - trade['price'].to_f).round(round_decimal) / pip_size) + channel_box_size_pips
            trade_take_profit_units = (trade['initialUnits'].to_i.abs / take_profit_pips * (trade_take_profit_pips + full_spread_pips)).round
            profit_loss_units       -= trade_take_profit_units
          end

          # Loop over trades closed and sum projected profit loss at the time the new order will trigger.
          if use_stop_losses
            trades_closed.times do |i|
              profit_loss_units -= (trades_units[i] / take_profit_pips.to_f * stop_loss_pips.to_f).ceil
            end
          end

          # Determine new order units.
          order_units = (initial_units * (trades_opened + 1) - profit_loss_units).floor
          trades_units_push(order_units) if use_stop_losses

          order_options = {
            order_price:      order_price.round(round_decimal),
            units:            order_units,
            take_profit_pips: -take_profit_pips
          }

          order_options.merge!(stop_loss_pips: +stop_loss_pips) if use_stop_losses
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
        fractal.confirmed_up?
      end

      def enter_short?
        fractal.confirmed_down?
      end

      def exit_long?
        trades_opened >= auto_take_profit_after && current_point_pf_a['xo'] == 'o' && xos_a_since_first_trade.size >= 3
      end

      def exit_short?
        trades_opened >= auto_take_profit_after && current_point_pf_a['xo'] == 'x' && xos_a_since_first_trade.size >= 3
      end

      def exit_position?
        exit_long? || exit_short?
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

      def channel_box_size_pips
        @channel_box_size_pips ||= channel_box_size_base * (max_xo_length + (max_xo_length - channel_box_size_median))
      end

      def take_profit_pips
        @take_profit_pips ||= take_profit_box_size_base * max_xo_length
      end

      def stop_loss_pips
        @stop_loss_pips ||= begin
          if stop_loss_on_position
            channel_box_size_pips * (max_trades + 1 - trades_opened)
          else
            stop_loss_box_size_base * max_xo_length
          end
        end
      end

      def initial_units_adjustment_factor
        @initial_units_adjustment_factor ||= initial_units_channel_base.to_f / max_xo_length.to_f
      end

      def max_xo_length
        @max_xo_length ||= indicator_pf_a['data'].map{ |point| point['attributes']['xo_length'] }.max
      end

      def current_point_pf_a
        @current_point_pf_a ||= indicator_pf_a['data'].last['attributes']
      end

      def points_pf_a
        @points_pf_a ||= indicator_pf_a['data'].map{ |point| point['attributes'] }
      end

      def indicator_pf_a
        @indicator_pf_a ||= begin
          results = { 'data' => [] }

          indicator_pf['data'].each_with_index do |data, i|
            next unless indicator_pf['data'][i]['attributes']['granularity'] == granularity[0].downcase &&
                        indicator_pf['data'][i]['attributes']['box_size'] == box_size[0] &&
                        indicator_pf['data'][i]['attributes']['reversal_amount'] == reversal_amount[0] &&
                        indicator_pf['data'][i]['attributes']['high_low_close'] == high_low_close[0]

            results['data'].push(data)
          end

          results
        end
      end

      def xos_a
        @xos_a ||= xos(points_pf_a, keys: ['xo_price', 'xo_length', 'xo', 'trend'])
      end

      def xos_a_since_first_trade
        @xos_a_since_first_trade ||= begin
          first_trade_id = oanda_active_trades.map{ |trade| trade['id'].to_i }.min
          first_trade    = oanda_active_trades.select{ |trade| trade['id'] == first_trade_id.to_s }.last
          xos(points_pf_b, columns: 0, keys: ['xo_price', 'xo_length', 'xo', 'trend', 'candle_at'], since: first_trade['openTime'])
        end
      end

      def initial_units
        $redis.get("#{key_base}:initial_units").to_i
      end

      def initial_units=(value)
        $redis.set("#{key_base}:initial_units", value.to_i.abs)
      end

      def trades_units
        $redis.smembers("#{key_base}:trades_units").map(&:to_i)
      end

      # Append to a unique sorted units array.
      def trades_units_push(value)
        $redis.sadd("#{key_base}:trades_units", value.to_i.abs)
      end

      def trades_units_reset
        $redis.del("#{key_base}:trades_units")
      end

      def trades_opened
        $redis.get("#{key_base}:trades_opened").to_i
      end

      def trades_opened=(value)
        $redis.set("#{key_base}:trades_opened", value)
      end

      def increment_trades_opened
        self.trades_opened = trades_opened + 1
      end

      def cleanup
        $redis.del("#{key_base}:initial_units")
        $redis.del("#{key_base}:trades_opened")
        $redis.del("#{key_base}:trades_units")
      end
    end
  end
end
