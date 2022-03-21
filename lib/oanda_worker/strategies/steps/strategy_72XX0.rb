# Strategy72XX0
#
#   Retirement Dynamic.
#   SPAM like strategy with incremented unit size orders at dynamic price channel and take profit levels.
#   Agimat indicator yellow arrow to determine entry.
#   Take profit factor will be determined by ranging or trending market.
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
    module Strategy72XX0
      # Initial Loop.

      # 0 Trades & 0 Orders.
      # Wait for indicator to signal trade entry and enter trade with take profit.
      def step_1
        trade_options

        if enter_long?
          self.initial_funnel_factor = funnel_factor

          backtest_logging("1 channel_box_size_pips: #{channel_box_size_pips}, funnel_factor: #{funnel_factor.round(5)}, take_profit_size_factor: #{take_profit_size_factor}, trending?: #{trending_market?}, xo_d: #{pf_current_point_a['xo']} #{pf_current_point_a['xo_length']}, xo_h1: #{pf_current_point_b['xo']} #{pf_current_point_b['xo_length']} #{pf_current_point_b['trend']}")

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
          self.initial_funnel_factor = funnel_factor

          backtest_logging("1 channel_box_size_pips: #{channel_box_size_pips}, funnel_factor: #{funnel_factor.round(5)}, take_profit_size_factor: #{take_profit_size_factor}, trending?: #{trending_market?}, xo_d: #{pf_current_point_a['xo']} #{pf_current_point_a['xo_length']}, xo_h1: #{pf_current_point_b['xo']} #{pf_current_point_b['xo_length']}  #{pf_current_point_b['trend']}")

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
        return false if exit_position? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps
        return false if oanda_active_orders.size == 0 && step_to(3) && queue_next_run
        false
      end

      # 1+ Trades & 0 Order.
      # Update take profit prices on all trades to match the latest trade's take profit price.
      def step_3
        return false if exit_position? && exit_trades_and_orders! && reset_steps
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
        return false if exit_position? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps
        return false if oanda_active_trades.size >= max_trades && step_to(5)

        order_options

        backtest_logging("#{oanda_active_trades.size + 1} channel_box_size_pips: #{channel_box_size_pips}, funnel_factor: #{funnel_factor.round(5)}, take_profit_size_factor: #{take_profit_size_factor}, trending?: #{trending_market?}, xo_d: #{pf_current_point_a['xo']} #{pf_current_point_a['xo_length']}, xo_h1: #{pf_current_point_b['xo']} #{pf_current_point_b['xo_length']} #{pf_current_point_b['trend']}")

        if oanda_long_trades.any?
          total_loss      = 0
          initial_units   = oanda_long_trades.map{ |trade| trade['initialUnits'].to_i }.min.abs
          order_price     = oanda_long_trades.map{ |trade| trade['price'].to_f }.min - channel_box_size_pips * pip_size
          # stop_loss_price = oanda_long_trades.map{ |trade| trade['stopLossOrder']['price'].to_f }.min
          # stop_loss       = stop_loss_pips * (max_trades - oanda_long_trades.size)

          # oanda_long_trades.each do |trade|
          #   trade_take_profit_pips = (trade['takeProfitOrder']['price'].to_f - trade['price'].to_f).round(round_decimal) / pip_size
          #   trade_take_profit_pips = trade_take_profit_pips - take_profit_pips
          #   total_loss             += trade['initialUnits'].to_i.abs * trade_take_profit_pips
          # end

          # order_units = (initial_units * (oanda_long_trades.size + 1) - (total_loss / take_profit_pips)).floor
          order_units = (oanda_long_trades.map{ |trade| trade['initialUnits'].to_f.abs}.max * units_increment_factor).floor
          raise OandaWorker::StrategyError, "Trying to create an order with 0 units. initial_units: #{initial_units}, oanda_short_trades.size: #{oanda_short_trades.size}, total_loss: #{total_loss}, take_profit_pips: #{take_profit_pips}" if order_units == 0

          order_options = {
            order_price:      order_price.round(round_decimal),
            units:            order_units,
            take_profit_pips: +take_profit_pips,
            # stop_loss_price:  stop_loss_price
            # stop_loss_pips:   -stop_loss
          }

          return false if create_order_at!(:long, order_options) && step_to(2)
        end

        if oanda_short_trades.any?
          total_loss      = 0
          initial_units   = oanda_short_trades.map{ |trade| trade['initialUnits'].to_i }.max.abs
          order_price     = oanda_short_trades.map{ |trade| trade['price'].to_f }.max + channel_box_size_pips * pip_size
          # stop_loss_price = oanda_short_trades.map{ |trade| trade['stopLossOrder']['price'].to_f }.max
          # stop_loss       = stop_loss_pips * (max_trades - oanda_short_trades.size)

          # oanda_short_trades.each do |trade|
          #   trade_take_profit_pips = (trade['takeProfitOrder']['price'].to_f - trade['price'].to_f).round(round_decimal) / pip_size
          #   trade_take_profit_pips = trade_take_profit_pips + take_profit_pips
          #   total_loss             -= trade['initialUnits'].to_i.abs * trade_take_profit_pips
          # end

          # order_units = (initial_units * (oanda_short_trades.size + 1) - (total_loss / take_profit_pips)).floor
          order_units = (oanda_short_trades.map{ |trade| trade['initialUnits'].to_f.abs}.max * units_increment_factor).floor
          raise OandaWorker::StrategyError, "Trying to create an order with 0 units. initial_units: #{initial_units}, oanda_short_trades.size: #{oanda_short_trades.size}, total_loss: #{total_loss}, take_profit_pips: #{take_profit_pips}" if order_units == 0

          order_options = {
            order_price:      order_price.round(round_decimal),
            units:            order_units,
            take_profit_pips: -take_profit_pips,
            # stop_loss_price:  stop_loss_price
            # stop_loss_pips:   +stop_loss
          }

          return false if create_order_at!(:short, order_options) && step_to(2)
        end

        false
      end

      # 5 Trades & 0 Orders.
      # Wait for trades to take profit or stop loss when max trades reached and restart initial loop.
      def step_5
        return false if exit_position? && exit_trades_and_orders! && reset_steps
        return false if oanda_active_trades.size == 0 && exit_orders! && reset_steps
        false
      end

      private

      def enter_long?
        fractal.confirmed_down? && pf_current_point_a['trend'] == 'up' && pf_current_point_b['trend'] == 'up'
        # return fractal.possible_down? if ranging_market?
        # return fractal.possible_down? && pf_current_point_b['trend'] == 'up' if trending_market?
      end

      def enter_short?
        fractal.confirmed_up? && pf_current_point_a['trend'] == 'down' && pf_current_point_b['trend'] == 'down'
        # return fractal.possible_up? if ranging_market?
        # return fractal.possible_up? && pf_current_point_b['trend'] == 'down' if trending_market?
      end

      def exit_long?
        return false if oanda_long_trades.empty?
        pf_current_point_a['trend'] == 'down' && pf_current_point_b['trend'] == 'down'
      end

      def exit_short?
        return false if oanda_short_trades.empty?
        pf_current_point_a['trend'] == 'up' && pf_current_point_b['trend'] == 'up'
      end

      def exit_position?
        exit_long? || exit_short?
      end

      def trending_market?
        return false

        daily_xo_length            = pf_current_point_a['xo_length']
        hourly_xo_trend_difference = (pf_current_point_b['xo_box_price'] - pf_current_point_b['trend_box_price']).abs / (pf_current_point_b['box_size'] * 10)

        daily_xo_length >= trending_market_xo_length && hourly_xo_trend_difference >= trending_market_xo_trend_difference

        # case pf_current_point_a['trend'].to_sym
        # when :down
        #   return pf_current_point_a['xo'] == 'o' && pf_current_point_a['xo_length'] >= trending_market_xo_length
        # when :up
        #   return pf_current_point_a['xo'] == 'x' && pf_current_point_a['xo_length'] >= trending_market_xo_length
        # end
      end

      def ranging_market?
        !trending_market?
      end

      def initial_funnel_factor
        $redis.get("#{key_base}:initial_funnel_factor").to_f
      end

      def initial_funnel_factor=(value)
        $redis.set("#{key_base}:initial_funnel_factor", value)
      end

      def channel_adjustment
        @channel_adjustment ||= begin
          adjustment = 0

          oanda_active_trades.size.times do |i|
            adjustment += channel_adjustment_seed * (i + 1)
          end

          adjustment
        end
      end

      def channel_box_size_pips
        @channel_box_size_pips ||= ((channel_increment * channel_box_size_factor + channel_adjustment) * funnel_factor).round(1)
      end

      def take_profit_pips
        @take_profit_pips ||= ((channel_increment * take_profit_size_factor + channel_adjustment) * funnel_factor).round(1)
      end

      def take_profit_size_factor
        @take_profit_size_factor ||= trending_market? ? take_profit_factor_trending : take_profit_factor_ranging
      end

      def stop_loss_pips
        @stop_loss_pips ||= take_profit_pips
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

      def pf_current_point_a
        @pf_current_point_a ||= pf_indicator_a['data'].last['attributes']
      end

      def pf_current_point_b
        @pf_current_point_b ||= pf_indicator_b['data'].last['attributes']
      end

      def pf_indicator_a
        @pf_indicator_a ||= begin
          results = { 'data' => [] }

          pf_indicator['data'].each_with_index do |data, i|
            next unless pf_indicator['data'][i]['attributes']['granularity'] == granularity[0].downcase &&
                        pf_indicator['data'][i]['attributes']['box_size'] == box_size[0] &&
                        pf_indicator['data'][i]['attributes']['reversal_amount'] == reversal_amount[0] &&
                        pf_indicator['data'][i]['attributes']['high_low_close'] == high_low_close[0]

            results['data'].push(data)
          end

          results
        end
      end

      def pf_indicator_b
        @pf_indicator_b ||= begin
          results = { 'data' => [] }

          pf_indicator['data'].each_with_index do |data, i|
            next unless pf_indicator['data'][i]['attributes']['granularity'] == granularity[1].downcase &&
                        pf_indicator['data'][i]['attributes']['box_size'] == box_size[1] &&
                        pf_indicator['data'][i]['attributes']['reversal_amount'] == reversal_amount[1] &&
                        pf_indicator['data'][i]['attributes']['high_low_close'] == high_low_close[1]

            results['data'].push(data)
          end

          results
        end
      end

      def cleanup
        $redis.del("#{key_base}:initial_funnel_factor")
        true
      end
    end
  end
end
