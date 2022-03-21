# Strategy47XX2
#
# Point and figure charts granularities and settings:
#
#   M5  high_low - determine trend + buy and sell siganls.
#   H1  close    - determine trend.
#   D   close    - determine trend.
#
# To enter a trade:
#
#   M5 chart should give a buy or sell signal.
#   M5 trend should be in the same direction.
#   H1 trend should be in the same direction.
#   D trend should be in the same direction.
#
# To exit a trade:
#
#   Uses a stop loss order on the trade which immediately gets replaced by an opposite side order when trade triggers to exit on a sell signal.
#
module Strategies
  module Steps
    module Strategy47XX2
      # 0 Trades & 0 Orders.
      # Wait for buy or sell signal.
      # Create order with stop loss.
      def step_1
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(2) && queue_next_run

        if create_long_order?
          return create_long_order! && queue_next_run
        end

        if create_short_order?
          return create_short_order! && queue_next_run
        end

        false
      end

      # 0 Trades & 1 Order.
      # Cancel order when trend changes.
      # Cancel order when risk is too high.
      # Update order & stop loss prices.
      def step_2
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active order! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 1

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

      # 1 Trade & 0 Orders.
      # Replace stop loss order with a mid price exit order & stop loss.
      def step_3
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1

        if oanda_long_trades.any?
          trade = oanda_long_trades.last
          create_short_order_as_stop_loss!(trade)
          return update_long_trade!(trade) && queue_next_run
        end

        if oanda_short_trades.any?
          trade = oanda_short_trades.last
          create_long_order_as_stop_loss!(trade)
          return update_short_trade!(trade) && queue_next_run
        end

        false
      end

      # 1 Trade, 1 Order.
      # Exit trade if contract has risen or fallen 18 consecutive boxes.
      # Update exit order & stop loss prices.
      # Create short order & stop loss when currently trading long and short order conditions are met and vice versa.
      def step_4
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        raise OandaWorker::StrategyStepError, "More than 1 active order! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 1

        if oanda_long_trades.any?
          raise OandaWorker::StrategyStepError, "No exit order! oanda_short_orders: #{oanda_short_orders.size}" if oanda_short_orders.size < 1
          exit_order = oanda_short_orders[0]
          trade      = oanda_long_trades.last

          if exit_long_trade?(trade)
            return false if exit_trades_and_orders! && reset_steps && queue_next_run
          end

          update_short_order_as_stop_loss!(exit_order)

          if create_short_order?
            return create_short_order! && queue_next_run
          end
        end

        if oanda_short_trades.any?
          raise OandaWorker::StrategyStepError, "No exit order! oanda_long_orders: #{oanda_long_orders.size}" if oanda_long_orders.size < 1
          exit_order = oanda_long_orders[0]
          trade      = oanda_short_trades.last

          if exit_short_trade?(trade)
            return false if exit_trades_and_orders! && reset_steps && queue_next_run
          end

          update_long_order_as_stop_loss!(exit_order)

          if create_long_order?
            return create_long_order! && queue_next_run
          end
        end

        false
      end

      # 1 Trade & 2 Orders.
      # Exit trade if contract has risen or fallen 18 consecutive boxes.
      # Update exit order & stop loss prices.
      # Update opposite order & stop loss prices.
      def step_5
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(3) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 1 && step_to(2) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && step_to(1) && queue_next_run
        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        raise OandaWorker::StrategyStepError, "More than 2 active orders! oanda_active_orders: #{oanda_active_orders.size}" if oanda_active_orders.size > 2

        if oanda_long_trades.any?
          raise OandaWorker::StrategyStepError, "No exit order! oanda_short_orders: #{oanda_short_orders.size}" if oanda_short_orders.size < 2
          exit_order = oanda_short_orders[1]
          trade      = oanda_long_trades.last

          if exit_long_trade?(trade)
            return false if exit_position! && exit_order!(exit_order) && step_to(2) && queue_next_run
          end

          oanda_short_orders.each do |order|
            if order['clientExtensions']['tag'] == tag_stop_loss
              update_short_order_as_stop_loss!(order)
              next
            end

            update_short_order!(order)
          end
        end

        if oanda_short_trades.any?
          raise OandaWorker::StrategyStepError, "No exit order! oanda_long_orders: #{oanda_long_orders.size}" if oanda_long_orders.size < 2
          exit_order = oanda_long_orders[1]
          trade      = oanda_short_trades.last

          if exit_short_trade?(trade)
            return false if exit_position! && exit_order!(exit_order) && step_to(2) && queue_next_run
          end

          oanda_long_orders.each do |order|
            if order['clientExtensions']['tag'] == tag_stop_loss
              update_long_order_as_stop_loss!(order)
              next
            end

            update_long_order!(order)
          end
        end

        false
      end

      private

      def create_long_order_as_stop_loss!(trade)
        create_long_order!(trade['initialUnits'], tag_stop_loss)
      end

      def create_short_order_as_stop_loss!(trade)
        create_short_order!(trade['initialUnits'], tag_stop_loss)
      end

      def create_long_order!(units = nil, tag = nil)
        if current_xo_a == 'o'
          xo_order_price    = (xos[-1].first['xo_price'] + 2 * box_size[0] * pip_size).round(round_decimal)
          xo_stop_loss_pips = -((xos[-1].last['xo_length'] + 2) * box_size[0])
        end

        if current_xo_a == 'x'
          xo_order_price    = (xos[-2].first['xo_price'] + 2 * box_size[0] * pip_size).round(round_decimal)
          xo_stop_loss_pips = -((xos[-2].last['xo_length'] + 2) * box_size[0])
        end

        backtest_logging("#{points_a.last['xo']} #{points_a.last['xo_length']} : #{points_a.last['trend']} #{points_a.last['trend_length']} - #{points_b.last['xo']} #{points_b.last['xo_length']} : #{points_b.last['trend']} #{points_b.last['trend_length']}")

        order_options = { order_price: xo_order_price, stop_loss_pips: xo_stop_loss_pips }
        order_options.merge!(units: units.to_i.abs.to_s) if units
        order_options.merge!(tag: tag) if tag
        return create_order_at!('long', order_options)
      end

      def create_short_order!(units = nil, tag = nil)
        if current_xo_a == 'x'
          xo_order_price    = (xos[-1].first['xo_price'] - 2 * box_size[0] * pip_size).round(round_decimal)
          xo_stop_loss_pips = +((xos[-1].last['xo_length'] + 2) * box_size[0])
        end

        if current_xo_a == 'o'
          xo_order_price    = (xos[-2].first['xo_price'] - 2 * box_size[0] * pip_size).round(round_decimal)
          xo_stop_loss_pips = +((xos[-2].last['xo_length'] + 2) * box_size[0])
        end

        backtest_logging("#{points_a.last['xo']} #{points_a.last['xo_length']} : #{points_a.last['trend']} #{points_a.last['trend_length']} - #{points_b.last['xo']} #{points_b.last['xo_length']} : #{points_b.last['trend']} #{points_b.last['trend_length']}")

        order_options = { order_price: xo_order_price, stop_loss_pips: xo_stop_loss_pips }
        order_options.merge!(units: units.to_i.abs.to_s) if units
        order_options.merge!(tag: tag) if tag
        return create_order_at!('short', order_options)
      end

      def update_long_order_as_stop_loss!(order)
        update_long_order!(order, order['units'], tag_stop_loss)
      end

      def update_short_order_as_stop_loss!(order)
        update_short_order!(order, order['units'], tag_stop_loss)
      end

      def update_long_order!(order, units = nil, tag = nil)
        if current_xo_a == 'o'
          current_order_price     = order['price'].to_f
          current_stop_loss_price = order['stopLossOnFill']['price'].to_f.round(round_decimal)
          xo_order_price          = (xos[-1].first['xo_price'] + 2 * box_size[0] * pip_size).round(round_decimal)
          xo_stop_loss_price      = (xos[-1].last['xo_price'] - 1 * box_size[0] * pip_size).round(round_decimal)

          if xo_stop_loss_price < current_stop_loss_price || xo_order_price < current_order_price
            order_options = { order_price: xo_order_price, stop_loss_price: xo_stop_loss_price }
            order_options.merge!(units: units.to_i.abs.to_s) if units
            order_options.merge!(tag: tag) if tag
            return update_order_at!('long', order['id'], order_options)
          end
        end
      end

      def update_short_order!(order, units = nil, tag = nil)
        if current_xo_a == 'x'
          current_order_price     = order['price'].to_f
          current_stop_loss_price = order['stopLossOnFill']['price'].to_f.round(round_decimal)
          xo_order_price          = (xos[-1].first['xo_price'] - 2 * box_size[0] * pip_size).round(round_decimal)
          xo_stop_loss_price      = (xos[-1].last['xo_price'] + 1 * box_size[0] * pip_size).round(round_decimal)

          if xo_stop_loss_price > current_stop_loss_price || xo_order_price > current_order_price
            order_options = { order_price: xo_order_price, stop_loss_price: xo_stop_loss_price }
            order_options.merge!(units: units.to_i.abs.to_s) if units
            order_options.merge!(tag: tag) if tag
            return update_order_at!('short', order['id'], order_options)
          end
        end
      end

      def update_long_trade!(trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
        exit_order!(trade['stopLossOrder'])
      end

      def update_short_trade!(trade)
        raise OandaWorker::StrategyStepError, "Trade #{trade['id']} should have a stop loss order!" unless trade['stopLossOrder']
        exit_order!(trade['stopLossOrder'])
      end

      def create_long_order?
        return false if current_trend_a == 'down'
        return false if current_trend_b == 'down'
        return false if current_trend_c == 'down'
        return false if current_xo_b == 'o'
        return false if current_xo_c == 'o'

        if current_xo_a == 'o'
          return true if xos[-1].last['xo_length'] <= risk_factor - 2
        end

        if current_xo_a == 'x'
          return true if xos[-2].last['xo_length'] <= risk_factor - 2 && current_close < (xos[-3].last['xo_price'] + 1 * box_size[0] * pip_size).round(round_decimal)
        end

        false
      end

      def create_short_order?
        return false if current_trend_a == 'up'
        return false if current_trend_b == 'up'
        return false if current_trend_c == 'up'
        return false if current_xo_b == 'x'
        return false if current_xo_c == 'x'

        if current_xo_a == 'x'
          return true if xos[-1].last['xo_length'] <= risk_factor - 2
        end

        if current_xo_a == 'o'
          return true if xos[-2].last['xo_length'] <= risk_factor - 2 && current_close > (xos[-3].last['xo_price'] - 1 * box_size[0] * pip_size).round(round_decimal)
        end

        false
      end

      def cancel_long_order?
        return true if current_trend_a == 'down'
        return true if current_trend_b == 'down'
        return true if current_trend_c == 'down'
        return true if current_xo_b == 'o'
        return true if current_xo_c == 'o'

        if current_xo_a == 'o'
          return true if xos[-1].last['xo_length'] > risk_factor - 2
        end

        false
      end

      def cancel_short_order?
        return true if current_trend_a == 'up'
        return true if current_trend_b == 'up'
        return true if current_trend_c == 'up'
        return true if current_xo_b == 'x'
        return true if current_xo_c == 'x'

        if current_xo_a == 'x'
          return true if xos[-1].last['xo_length'] > risk_factor - 2
        end

        false
      end

      def exit_long_trade?(trade)
        return false if current_xo_a == 'x'

        if current_xo_a == 'o' && xos[-2].last['xo_length'] >= exit_factor
          # 18 - 1 because the trade price will not always be spot on with the box price the order was placed on.
          if xos[-2].last['xo_price'] >= (trade['price'].to_f + (exit_factor - 1) * box_size[0] * pip_size).round(round_decimal) && xos[-1].last['xo_price'] > trade['price'].to_f
            return true
          end
        end

        false
      end

      def exit_short_trade?(trade)
        return false if current_xo_a == 'o'

        if current_xo_a == 'x' && xos[-2].last['xo_length'] >= exit_factor
          # 18 - 1 because the trade price will not always be spot on with the box price the order was placed on.
          if xos[-2].last['xo_price'] <= (trade['price'].to_f - (exit_factor - 1) * box_size[0] * pip_size).round(round_decimal) && xos[-1].last['xo_price'] < trade['price'].to_f
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
              'tag' => tag_order
            }
          }
        }
      end

      def cleanup
        unlock!(:all)
      end

      def backtest_logging(message)
        return unless backtesting?
        data = @data.merge({
          published_at: time_now_utc,
          level:        :default,
          message:      message
        })
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      end

      def indicator_options
        @indicator_options ||= {
          instrument: instrument,
          granularity: "#{granularity[0]},#{granularity[1]},#{granularity[2]},#{granularity[3]}",
          box_size: "#{box_size[0]},#{box_size[1]},#{box_size[2]},#{box_size[3]}",
          reversal_amount: "#{reversal_amount[0]},#{reversal_amount[1]},#{reversal_amount[2]},#{reversal_amount[3]}",
          high_low_close: "#{high_low_close[0]},#{high_low_close[1]},#{high_low_close[2]},#{high_low_close[3]}",
          count: '300,1,1,1'
        }
      end

      def indicator
        @indicator ||= oanda_service_client.indicator(:point_and_figure, indicator_options).show
        raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. indicator['data']: #{@indicator['data']}" if @indicator['data'].empty?
        @indicator
      end

      def indicator_a
        @indicator_a ||= begin
          results = { 'data' => [] }

          indicator['data'].each_with_index do |data, i|
            next unless indicator['data'][i]['attributes']['granularity'] == granularity[0].downcase &&
                        indicator['data'][i]['attributes']['box_size'] == box_size[0] &&
                        indicator['data'][i]['attributes']['reversal_amount'] == reversal_amount[0] &&
                        indicator['data'][i]['attributes']['high_low_close'] == high_low_close[0]

            results['data'].push(data)
          end

          results
        end
      end

      def indicator_b
        @indicator_b ||= begin
          results = { 'data' => [] }

          indicator['data'].each_with_index do |data, i|
            next unless indicator['data'][i]['attributes']['granularity'] == granularity[1].downcase &&
                        indicator['data'][i]['attributes']['box_size'] == box_size[1] &&
                        indicator['data'][i]['attributes']['reversal_amount'] == reversal_amount[1] &&
                        indicator['data'][i]['attributes']['high_low_close'] == high_low_close[1]

            results['data'].push(data)
          end

          results
        end
      end

      def indicator_c
        @indicator_c ||= begin
          results = { 'data' => [] }

          indicator['data'].each_with_index do |data, i|
            next unless indicator['data'][i]['attributes']['granularity'] == granularity[2].downcase &&
                        indicator['data'][i]['attributes']['box_size'] == box_size[2] &&
                        indicator['data'][i]['attributes']['reversal_amount'] == reversal_amount[2] &&
                        indicator['data'][i]['attributes']['high_low_close'] == high_low_close[2]

            results['data'].push(data)
          end

          results
        end
      end

      def points_a
        @points_a ||= indicator_a['data'].map{ |point| point['attributes'] }
      end

      def points_b
        @points_b ||= indicator_b['data'].map{ |point| point['attributes'] }
      end

      def points_c
        @points_c ||= indicator_c['data'].map{ |point| point['attributes'] }
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
          last_xo = points_a.last['xo']

          points_a.each do |point|
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

      def current_xo_a
        @current_xo_a ||= points_a.last['xo']
      end

      def current_xo_b
        @current_xo_b ||= points_b.last['xo']
      end

      def current_xo_c
        @current_xo_c ||= points_c.last['xo']
      end

      def current_trend_a
        @current_trend_a ||= points_a.last['trend']
      end

      def current_trend_b
        @current_trend_b ||= points_b.last['trend']
      end

      def current_trend_c
        @current_trend_c ||= points_c.last['trend']
      end

      def current_close
        @current_close ||= close(include_incomplete_candles: true, refresh: true)
      end
    end
  end
end
