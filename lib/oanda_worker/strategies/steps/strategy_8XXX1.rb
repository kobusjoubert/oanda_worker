# Strategy8XXX1
#
#   Advanced Patterns (Gartleys, Bats & Cyphers) Parent.
#
# To enter a trade:
#
#   Wait for a pattern to give buy or sell order signal.
#   Place the valid pattern orders.
#   Remove the orders when the pattern is invalidated.
#
# To exit a trade:
#
#   Wait for stop loss to trigger.
#   Wait for target 1 to trigger.
#   Rolls stops to break even.
#   Keep on rolling stops down unitl stopped out.
#
# Notes
#
#   Only place orders if risk to reward ration is at least a 1:1.
#
module Strategies
  module Steps
    module Strategy8XXX1
      attr_reader :bullish_cyphers, :bearish_cyphers, :bullish_gartleys, :bearish_gartleys, :bullish_bats, :bearish_bats,
                  :targets, :stops, :risk_pips, :min_pattern_pips, :max_pattern_pips, :trading_days, :trading_times, :atr, :sma_leading, :sma_lagging, :deep_gartley

      def initialize(options = {})
        super
        options.symbolize_keys!

        options.each do |key, value|
          self.send("#{key}=", value) if self.respond_to?("#{key}=")
        end

        extend Object.const_get("Strategies::Settings::Strategy#{strategy}#{granularity}")
        settings!

        if [1, 2, 3, 4].include?(step)
          candles(smooth: true, include_incomplete_candles: false)

          @atr = Indicators::AverageTrueRange.new(candles: candles, count: stops.map{ |_, value| value if value[0] == :atr }.compact.first[1]).point if stops.map{ |_, value| value[0] }.include?(:atr)

          if trading_days[:cypher].include?(week_day) && times_inside?(trading_times[:cypher])
            @bullish_cyphers = Patterns::Cypher.new(
              candles:          candles,
              count:            candles_required,
              # min_pattern_pips: min_pattern_pips[:cypher],
              # max_pattern_pips: max_pattern_pips[:cypher],
              pip_size:         pip_size,
              round_decimal:    round_decimal,
              granularity:      granularity,
              trend:            :bullish
            )

            @bearish_cyphers = Patterns::Cypher.new(
              candles:          candles,
              count:            candles_required,
              # min_pattern_pips: min_pattern_pips[:cypher],
              # max_pattern_pips: max_pattern_pips[:cypher],
              pip_size:         pip_size,
              round_decimal:    round_decimal,
              granularity:      granularity,
              trend:            :bearish
            )
          end

          if trading_days[:gartley].include?(week_day) && times_inside?(trading_times[:gartley])
            @bullish_gartleys = Patterns::Gartley.new(
              candles:          candles,
              count:            candles_required,
              # min_pattern_pips: min_pattern_pips[:gartley],
              # max_pattern_pips: max_pattern_pips[:gartley],
              pip_size:         pip_size,
              round_decimal:    round_decimal,
              granularity:      granularity,
              trend:            :bullish,
              deep_gartley:     deep_gartley
            )

            @bearish_gartleys = Patterns::Gartley.new(
              candles:          candles,
              count:            candles_required,
              # min_pattern_pips: min_pattern_pips[:gartley],
              # max_pattern_pips: max_pattern_pips[:gartley],
              pip_size:         pip_size,
              round_decimal:    round_decimal,
              granularity:      granularity,
              trend:            :bearish,
              deep_gartley:     deep_gartley
            )
          end

          if trading_days[:bat].include?(week_day) && times_inside?(trading_times[:bat])
            @bullish_bats = Patterns::Bat.new(
              candles:          candles,
              count:            candles_required,
              # min_pattern_pips: min_pattern_pips[:bat],
              # max_pattern_pips: max_pattern_pips[:bat],
              pip_size:         pip_size,
              round_decimal:    round_decimal,
              granularity:      granularity,
              trend:            :bullish
            )

            @bearish_bats = Patterns::Bat.new(
              candles:          candles,
              count:            candles_required,
              # min_pattern_pips: min_pattern_pips[:bat],
              # max_pattern_pips: max_pattern_pips[:bat],
              pip_size:         pip_size,
              round_decimal:    round_decimal,
              granularity:      granularity,
              trend:            :bearish
            )
          end

          # @bullish_cyphers.points.clear && @bearish_cyphers.points.clear unless trading_days[:cypher].include?(week_day)
          # @bullish_gartleys.points.clear && @bearish_gartleys.points.clear unless trading_days[:gartley].include?(week_day)
          # @bullish_bats.points.clear && @bearish_bats.points.clear unless trading_days[:bat].include?(week_day)
        end

        if [9].include?(step)
          candles(smooth: true, include_incomplete_candles: false)

          if targets.map{ |_, value| value[1] }.include?(:tsl)
            @atr         = Indicators::AverageTrueRange.new(candles: candles, count: 7).point
            @sma_leading = Overlays::SimpleMovingAverage.new(candles: candles, count: 3).point
            @sma_lagging = Overlays::SimpleMovingAverage.new(candles: candles, count: 5).point
          end
        end

        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && backtest_export && cleanup && reset_steps
      end

      # Patterns!
      # Wait for first pattern.
      # Place first order with stop loss.

      # 0 Trades & 0 Orders.
      # Wait for the first bullish and or bearish pattern to form.
      # Place the orders closest to the current market price.
      # Place stop loss order.
      def step_1
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size >= 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(6) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(7) && queue_next_run

        if create_long_order?
          return false if create_long_entry_order! && step_to(2) && queue_next_run
        end

        if create_short_order?
          return false if create_short_entry_order! && step_to(3) && queue_next_run
        end

        false
      end

      # Orders!
      # Wait for an order to be triggered and place target orders.
      # Wait for a pattern to be invalidated and remove the order.
      # Make sure the current valid patterns match the current orders.

      # 0 Trades & 1 Bullish Order.
      # Wait for the bullish order to trigger.
      # Cancel order if bullish pattern was invalidated.
      # Cancel order if bullish pattern does not match the current bullish order.
      # See if a bearish pattern has formed and place the order.
      def step_2
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && reset_steps && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size >= 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(6) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(7) && queue_next_run

        pattern = bullish_pattern_to_use
        order   = oanda_long_orders.last

        return false if pattern.nil? && exit_orders! && reset_steps
        return false if adjusted_order_price(:long, pattern[:d], order['stopLossOnFill']['price']) != order['price'].to_f && exit_orders! && reset_steps && queue_next_run

        if create_short_order?
          return false if create_short_entry_order! && step_to(4) && queue_next_run
        end

        false
      end

      # 0 Trades & 1 Bearish Order.
      # Wait for the bearish order to trigger.
      # Cancel order if bearish pattern was invalidated.
      # Cancel order if bearish pattern does not match the current bearish order.
      # See if a bullish pattern has formed and place the order.
      def step_3
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && reset_steps && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size >= 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(6) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(7) && queue_next_run

        pattern = bearish_pattern_to_use
        order   = oanda_short_orders.last

        return false if pattern.nil? && exit_orders! && reset_steps
        return false if adjusted_order_price(:short, pattern[:d], order['stopLossOnFill']['price']) != order['price'].to_f && exit_orders! && reset_steps && queue_next_run

        if create_long_order?
          return false if create_long_entry_order! && step_to(4) && queue_next_run
        end

        false
      end

      # 0 Trades, 1 Bullish & 1 Bearish Order.
      # Wait for a bullish or bearish order to trigger. If both triggered, the last one will close out the first one.
      # Cancel order if the bullish or bearish pattern was invalidated.
      # Cancel order if bullish or bearish pattern does not match the current orders respectively.
      def step_4
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 0 && oanda_short_orders.size == 0 && backtest_export && reset_steps && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && backtest_export && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && backtest_export && step_to(3) && queue_next_run
        return false if oanda_active_trades.size >= 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(6) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(7) && queue_next_run

        bullish_pattern = bullish_pattern_to_use
        bearish_pattern = bearish_pattern_to_use
        long_order      = oanda_long_orders.last
        short_order     = oanda_short_orders.last

        return false if bullish_pattern.nil? && exit_orders!(:long) && step_to(3)
        return false if bearish_pattern.nil? && exit_orders!(:short) && step_to(2)

        return false if adjusted_order_price(:long, bullish_pattern[:d], long_order['stopLossOnFill']['price']) != long_order['price'].to_f && exit_orders!(:long) && step_to(3) && queue_next_run
        return false if adjusted_order_price(:short, bearish_pattern[:d], short_order['stopLossOnFill']['price']) != short_order['price'].to_f && exit_orders!(:short) && step_to(2) && queue_next_run

        false
      end

      # Trades!
      # Cancel opposite side order.
      # TODO: What happens when a trade was triggered, and immediately the stop loss was triggered before getting to any of the steps below?

      # 2 Trades & 0 Orders.
      # This should not be happening!
      # Cancel trades and reset steps!
      def step_5
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(6) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(7) && queue_next_run

        return false if exit_trades_and_orders! && reset_steps

        false
      end

      # 1 Trade & 1 Order.
      # Cancel opposite side order if there is one.
      def step_6
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size >= 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 0 && step_to(7) && queue_next_run

        return false if oanda_short_trades.size == 1 && oanda_long_orders.any? && exit_orders!(:long) && step_to(7) && queue_next_run
        return false if oanda_long_trades.size == 1 && oanda_short_orders.any? && exit_orders!(:short) && step_to(7) && queue_next_run

        false
      end

      # Targets!
      # Wait for trade to exit.
      # Place target orders.

      # 1 Trade & 0 Orders.
      # Place target order 1.
      # If order immediately gets filled when created, we need to roll stops to break even and keep rolling stops down as new swings occur.
      def step_7
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 0 && step_to(2) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 0 && oanda_short_orders.size == 1 && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_long_orders.size == 1 && oanda_short_orders.size == 1 && step_to(4) && queue_next_run
        return false if oanda_active_trades.size >= 2 && step_to(5) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_active_orders.size == 1 && step_to(6) && queue_next_run

        if oanda_long_trades.any?
          if create_short_target_order!(1, oanda_long_trades.last)
            return false if step_to(8) && queue_next_run
          else
            return false if oanda_order['orderFillTransaction'] && oanda_order['orderFillTransaction']['tradeReduced'] && roll_stop_to_break_even! && step_to(9) && queue_next_run
          end
        end

        if oanda_short_trades.any?
          if create_long_target_order!(1, oanda_short_trades.last)
            return false if step_to(8) && queue_next_run
          else
            return false if oanda_order['orderFillTransaction'] && oanda_order['orderFillTransaction']['tradeReduced'] && roll_stop_to_break_even! && step_to(9) && queue_next_run
          end
        end

        false
      end

      # 1 Trade & 1 Target Order.
      # Wait for stop loss to trigger.
      # Wait for target 1 to trigger and roll stops to break even.
      # Monitor price action moving against you.
      # Keep on updating targets according to the new d leg value.
      def step_8
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size >= 1 && step_to(10) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && backtest_export && reset_steps

        if oanda_active_trades.size == 1 && oanda_limit_orders.size == 0
          return false if roll_stop_to_break_even! && step_to(9) && queue_next_run
        end

        if d_leg_extended?
          return false if update_d_leg! && exit_orders! && step_to(7) && queue_next_run
        end

        false
      end

      # 1 Trade & 0 Target Orders.
      # Wait for trade to exit.
      # Keep rolling stops down as new swings occur.
      #
      # Describing a short trade:
      #
      #   1) Keep track of lowest low on each candle.
      #   2) As soon as the sma_leading crosses over the sma_lagging, keep track of the highest high with the ATR of the highest high.
      #      Also wait for the lowest low to be violated again and update the stop to the ATR above the high, as long as the new stop is lower than the current stop.
      #      Go back to 1.
      def step_9
        return false if oanda_active_trades.size == 1 && oanda_limit_orders.size == 1 && step_to(8) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size >= 1 && step_to(10) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && backtest_export && reset_steps

        if oanda_long_trades.any?
          self.highest_high      = current_candle['mid']['h'].to_f unless highest_high
          self.sma_crossed_under = true if sma_leading < sma_lagging

          unless sma_crossed_under?
            self.highest_high = current_candle['mid']['h'].to_f if current_candle['mid']['h'].to_f > highest_high
          end

          if sma_crossed_under?
            unless lowest_low
              self.lowest_low        = current_candle['mid']['l'].to_f
              self.atr_below_the_low = atr
            end

            if current_candle['mid']['l'].to_f < lowest_low
              self.lowest_low        = current_candle['mid']['l'].to_f
              self.atr_below_the_low = atr
            end

            if current_candle['mid']['h'].to_f > highest_high
              roll_stop_to_atr_below_the_low!
              self.highest_high      = current_candle['mid']['h'].to_f
              self.lowest_low        = nil
              self.atr_below_the_low = nil
              self.sma_crossed_under = false
            end
          end
        end

        if oanda_short_trades.any?
          self.lowest_low       = current_candle['mid']['l'].to_f unless lowest_low
          self.sma_crossed_over = true if sma_leading > sma_lagging

          unless sma_crossed_over?
            self.lowest_low = current_candle['mid']['l'].to_f if current_candle['mid']['l'].to_f < lowest_low
          end

          if sma_crossed_over?
            unless highest_high
              self.highest_high       = current_candle['mid']['h'].to_f
              self.atr_above_the_high = atr
            end

            if current_candle['mid']['h'].to_f > highest_high
              self.highest_high       = current_candle['mid']['h'].to_f
              self.atr_above_the_high = atr
            end

            if current_candle['mid']['l'].to_f < lowest_low
              roll_stop_to_atr_above_the_high!
              self.lowest_low         = current_candle['mid']['l'].to_f
              self.highest_high       = nil
              self.atr_above_the_high = nil
              self.sma_crossed_over   = false
            end
          end
        end

        false
      end

      # 0 Trades & 1+ Target Order.
      # Cancel remaining orders.
      # Reset steps.
      def step_10
        return false if oanda_active_trades.size == 1 && oanda_limit_orders.size == 1 && step_to(8) && queue_next_run
        return false if oanda_active_trades.size == 1 && oanda_limit_orders.size == 0 && step_to(9) && queue_next_run
        return false if oanda_active_trades.size == 0 && oanda_active_orders.size == 0 && backtest_export && reset_steps

        return false if exit_trades_and_orders! && backtest_export && reset_steps && queue_next_run

        false
      end

      private

      # # To be defined in child!
      # def create_long_order?
      # end

      # # To be defined in child!
      # def create_short_order?
      # end

      def d_leg_extended?
        if oanda_long_trades.any?
          return current_candle['mid']['l'].to_f < (bullish_pattern[:d_extended] || bullish_pattern[:d])
        end

        if oanda_short_trades.any?
          return current_candle['mid']['h'].to_f > (bearish_pattern[:d_extended] || bearish_pattern[:d])
        end

        false
      end

      def stop_loss_price(type, pattern, a_point, x_point)
        case type
        when :long
          return (x_point - atr * (stops[pattern][2] || 1)).round(round_decimal) if stops[pattern].first == :atr
          return extension(a_point, x_point, stops[pattern][1]).round(round_decimal) if stops[pattern].first == :extension
        when :short
          return (x_point + atr * (stops[pattern][2] || 1)).round(round_decimal) if stops[pattern].first == :atr
          return extension(a_point, x_point, stops[pattern][1]).round(round_decimal) if stops[pattern].first == :extension
        end
      end

      def retracement_price(point_1, point_2, percentage)
        point_2.to_f + ((point_1.to_f - point_2.to_f) * percentage)
      end

      def extension(point_1, point_2, ratio)
        point_1.to_f + ((point_2.to_f - point_1.to_f) * ratio.to_f)
      end

      # # To be defined in child!
      # def bullish_pattern_to_use
      # end
      #
      # # To be defined in child!
      # def bearish_pattern_to_use
      # end

      def units(type)
        (calculated_units_from_balance(config[:margin], type) || config[:units]).floor
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

      def adjusted_order_price(type, order_price, stop_loss_price)
        stop_loss_price    = stop_loss_price.to_f
        order_price        = order_price.to_f
        order_to_stop_pips = (stop_loss_price - order_price).abs / pip_size

        if order_to_stop_pips > risk_pips
          pip_difference = order_to_stop_pips - risk_pips

          order_price =
            case type
            when :long
              order_price - (pip_difference * pip_size)
            when :short
              order_price + (pip_difference * pip_size)
            end
        end

        order_price.round(round_decimal)
      end

      # Buy Limit.
      def create_long_entry_order!
        order_options

        pattern              = bullish_pattern_to_use
        stop_loss_price      = stop_loss_price(:long, pattern[:pattern], pattern[:a], pattern[:x])
        order_price          = adjusted_order_price(:long, pattern[:d], stop_loss_price)
        order_units          = units(:long)
        self.bullish_pattern = pattern

        candles(smooth: true, include_incomplete_candles: true, refresh: true)
        return false if current_candle['mid']['l'].to_f < order_price

        order_options = {
          order_price:     order_price.round(round_decimal),
          stop_loss_price: stop_loss_price.round(round_decimal),
          units:           order_units
        }

        message = "#{pattern[:pattern]} ->"
        message << " x: #{pattern[:x]} (#{Time.parse(pattern[:x_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", a: #{pattern[:a]} (#{Time.parse(pattern[:a_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", b: #{pattern[:b]} (#{Time.parse(pattern[:b_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", c: #{pattern[:c]} (#{Time.parse(pattern[:c_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", d: #{pattern[:d]}"
        message << ", d_adjusted: #{order_price}" if order_price != pattern[:d]
        activity_logging(message)

        create_long_order!(order_options)
      end

      # Sell Limit.
      def create_short_entry_order!
        order_options

        pattern              = bearish_pattern_to_use
        stop_loss_price      = stop_loss_price(:short, pattern[:pattern], pattern[:a], pattern[:x])
        order_price          = adjusted_order_price(:short, pattern[:d], stop_loss_price)
        order_units          = units(:short)
        self.bearish_pattern = pattern

        candles(smooth: true, include_incomplete_candles: true, refresh: true)
        return false if current_candle['mid']['h'].to_f > order_price

        order_options = {
          order_price:     order_price.round(round_decimal),
          stop_loss_price: stop_loss_price.round(round_decimal),
          units:           order_units
        }

        message = "#{pattern[:pattern]} ->"
        message << " x: #{pattern[:x]} (#{Time.parse(pattern[:x_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", a: #{pattern[:a]} (#{Time.parse(pattern[:a_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", b: #{pattern[:b]} (#{Time.parse(pattern[:b_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", c: #{pattern[:c]} (#{Time.parse(pattern[:c_date]).strftime('%Y-%m-%d %H:%M')})"
        message << ", d: #{pattern[:d]}"
        message << ", d_adjusted: #{order_price}" if order_price != pattern[:d]
        activity_logging(message)

        create_short_order!(order_options)
      end

      # Buy Limit.
      def create_long_target_order!(number, trade)
        target_order_options

        pattern     = bearish_pattern
        order_units = (units(:short) / targets[pattern[:pattern].to_sym].size).round

        order_price =
          case pattern[:pattern].to_sym
          when :gartley, :bat
            retracement_price(pattern[:a], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][number - 1])
          when :cypher
            retracement_price(pattern[:c], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][number - 1])
          end

        order_options = {
          order_price: order_price.round(round_decimal),
          units:       order_units
        }

        create_long_order!(order_options)
      end

      # Sell Limit.
      def create_short_target_order!(number, trade)
        target_order_options

        pattern     = bullish_pattern
        order_units = (units(:long) / targets[pattern[:pattern].to_sym].size).round

        order_price =
          case pattern[:pattern].to_sym
          when :gartley, :bat
            retracement_price(pattern[:a], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][number - 1])
          when :cypher
            retracement_price(pattern[:c], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][number - 1])
          end

        order_options = {
          order_price: order_price.round(round_decimal),
          units:       order_units
        }

        create_short_order!(order_options)
      end

      # Buy Stop.
      def create_long_stop_order!
        stop_order_options

        pattern     = bearish_pattern
        order_price = pattern[:d]
        order_units = (units(:short) / targets[pattern[:pattern].to_sym].size).round

        order_options = {
          order_price: order_price.round(round_decimal),
          units:       order_units
        }

        create_long_order!(order_options)
      end

      # Sell Stop.
      def create_short_stop_order!
        stop_order_options

        pattern     = bullish_pattern
        order_price = pattern[:d]
        order_units = (units(:long) / targets[pattern[:pattern].to_sym].size).round

        order_options = {
          order_price: order_price.round(round_decimal),
          units:       order_units
        }

        create_short_order!(order_options)
      end

      def roll_stop_to_break_even!
        trade               = oanda_active_trades.last
        new_stop_loss_price = trade['price'].to_f

        unless trade['stopLossOrder']['price'].to_f == new_stop_loss_price
          options = {
            id:        trade['id'],
            stop_loss: new_stop_loss_price.round(round_decimal)
          }

          return true if update_trade!(options)
        end

        false
      end

      def roll_stop_to_atr_above_the_high!
        trade               = oanda_active_trades.last
        new_stop_loss_price = highest_high + atr_above_the_high

        unless trade['stopLossOrder']['price'].to_f <= new_stop_loss_price
          options = {
            id:        trade['id'],
            stop_loss: new_stop_loss_price.round(round_decimal)
          }

          return true if update_trade!(options)
        end

        false
      end

      def roll_stop_to_atr_below_the_low!
        trade               = oanda_active_trades.last
        new_stop_loss_price = lowest_low - atr_below_the_low

        unless trade['stopLossOrder']['price'].to_f >= new_stop_loss_price
          options = {
            id:        trade['id'],
            stop_loss: new_stop_loss_price.round(round_decimal)
          }

          return true if update_trade!(options)
        end

        false
      end

      def update_d_leg!
        if oanda_long_trades.any?
          self.bullish_pattern = bullish_pattern.merge(d_extended: current_candle['mid']['l'].to_f)
        end

        if oanda_short_trades.any?
          self.bearish_pattern = bearish_pattern.merge(d_extended: current_candle['mid']['h'].to_f)
        end

        true
      end

      def bullish_pattern
        JSON.parse($redis.get("#{key_base}:bullish_pattern")).symbolize_keys
      end

      def bullish_pattern=(value)
        $redis.set("#{key_base}:bullish_pattern", value.to_json)
      end

      def bearish_pattern
        JSON.parse($redis.get("#{key_base}:bearish_pattern")).symbolize_keys
      end

      def bearish_pattern=(value)
        $redis.set("#{key_base}:bearish_pattern", value.to_json)
      end

      def highest_high
        $redis.get("#{key_base}:highest_high") && $redis.get("#{key_base}:highest_high").to_f.round(round_decimal)
      end

      def highest_high=(value)
        if value.nil?
          $redis.del("#{key_base}:highest_high")
        else
          $redis.set("#{key_base}:highest_high", value.to_f.round(round_decimal))
        end
      end

      def lowest_low
        $redis.get("#{key_base}:lowest_low") && $redis.get("#{key_base}:lowest_low").to_f.round(round_decimal)
      end

      def lowest_low=(value)
        if value.nil?
          $redis.del("#{key_base}:lowest_low")
        else
          $redis.set("#{key_base}:lowest_low", value.to_f.round(round_decimal))
        end
      end

      # Returns true if there are a string (true or false) saved at #{key_base}:sma_crossed_over.
      # Returns false if the key does not exist.
      def sma_crossed_over
        !!$redis.get("#{key_base}:sma_crossed_over")
      end
      alias :sma_crossed_over? :sma_crossed_over

      def sma_crossed_over=(value)
        if value.nil? || value == false
          $redis.del("#{key_base}:sma_crossed_over")
        else
          $redis.set("#{key_base}:sma_crossed_over", value)
        end
      end

      # Returns true if there are a string (true or false) saved at #{key_base}:sma_crossed_under.
      # Returns false if the key does not exist.
      def sma_crossed_under
        !!$redis.get("#{key_base}:sma_crossed_under")
      end
      alias :sma_crossed_under? :sma_crossed_under

      def sma_crossed_under=(value)
        if value.nil? || value == false
          $redis.del("#{key_base}:sma_crossed_under")
        else
          $redis.set("#{key_base}:sma_crossed_under", value)
        end
      end

      def atr_above_the_high
        $redis.get("#{key_base}:atr_above_the_high") && $redis.get("#{key_base}:atr_above_the_high").to_f.round(round_decimal)
      end

      def atr_above_the_high=(value)
        if value.nil?
          $redis.del("#{key_base}:atr_above_the_high")
        else
          $redis.set("#{key_base}:atr_above_the_high", value)
        end
      end

      def atr_below_the_low
        $redis.get("#{key_base}:atr_below_the_low") && $redis.get("#{key_base}:atr_below_the_low").to_f.round(round_decimal)
      end

      def atr_below_the_low=(value)
        if value.nil?
          $redis.del("#{key_base}:atr_below_the_low")
        else
          $redis.set("#{key_base}:atr_below_the_low", value)
        end
      end

      def backtest_export
        trade, entry_date, entry_time, exit_date, exit_time, target_prices, pos_exit_prices, pos_total_spreads = *super
        return true unless backtesting? && trade

        type = trade['initialUnits'].to_i >= 0 ? :long : :short

        pattern =
          case type
          when :long
            bullish_pattern
          when :short
            bearish_pattern
          end

        targets_count = targets[pattern[:pattern].to_sym].size

        # Calculate target_prices if parent backtest_export couldn't figure it out.
        if target_prices.empty?
          case pattern[:pattern].to_sym
          when :gartley, :bat
            target_prices[0] = retracement_price(pattern[:a], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][0])
            target_prices[1] = retracement_price(pattern[:a], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][1]) if targets.size >= 2
          when :cypher
            target_prices[0] = retracement_price(pattern[:c], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][0])
            target_prices[1] = retracement_price(pattern[:c], pattern[:d_extended] || pattern[:d], targets[pattern[:pattern].to_sym][1]) if targets.size >= 2
          end
        end

        # Export to tab delimited file for import into Google Sheets.
        sheet_values = {
          pattern:              pattern[:pattern].capitalize,
          entry_date:           entry_date,
          entry_time:           entry_time.split(':')[0..1].join(':'),
          exit_date:            exit_date,
          exit_time:            exit_time.split(':')[0..1].join(':'),
          entry_price:          trade['price'],
          stop_loss:            trade['stopLossOrder']['price'],
          target_1_price:       target_prices[0],
          target_2_price:       target_prices[1],
          pos_1_exit_price:     pos_exit_prices[0],
          pos_2_exit_price:     targets_count > 1 ? pos_exit_prices[1] || pos_exit_prices[0] : nil,
          pos_1_total_spread:   pos_total_spreads[0],
          pos_2_total_spread:   targets_count > 1 ? pos_total_spreads[1] || pos_total_spreads[0] : nil,
          x_price:              pattern[:x],
          a_price:              pattern[:a],
          b_price:              pattern[:b],
          c_price:              pattern[:c],
          d_price:              pattern[:d]
        }

        backtest_exporting(sheet_values)

        # Export to ; delimited file for import into TradingView Charts.
        shape =
          case pattern[:pattern].to_sym
          when :gartley, :bat
            'xabcd_pattern'
          when :cypher
            'cypher_pattern'
          end

        x_date = Time.parse(pattern[:x_date])
        a_date = Time.parse(pattern[:a_date])
        b_date = Time.parse(pattern[:b_date])
        c_date = Time.parse(pattern[:c_date])
        d_date = a_date + ((c_date - a_date) / 3 * 4)

        points = [
          { time: x_date.to_i, price: pattern[:x].to_f },
          { time: a_date.to_i, price: pattern[:a].to_f },
          { time: b_date.to_i, price: pattern[:b].to_f },
          { time: c_date.to_i, price: pattern[:c].to_f },
          { time: d_date.to_i, price: pattern[:d].to_f }
        ]

        green_line       = '#93c47d'
        green_background = '#d9ead3'
        red_line         = '#e06666'
        red_background   = '#f4cccc'

        if trade['stopLossOrder']['price'] == target_prices[0]
          color_line       = red_line
          color_background = red_background
        else
          color_line       = green_line
          color_background = green_background
        end

        overrides = {
          transparency:    '80',
          fontsize:        '10',
          color:           color_line,
          backgroundColor: color_background
        }

        chart_values = {
          text:      pattern[:pattern],
          shape:     shape,
          points:    points.to_json,
          overrides: overrides.to_json
        }

        backtest_chart_plotting(chart_values)

        true
      end

      def cleanup
        super
        $redis.del("#{key_base}:bullish_pattern")
        $redis.del("#{key_base}:bearish_pattern")
        $redis.del("#{key_base}:highest_high")
        $redis.del("#{key_base}:lowest_low")
        $redis.del("#{key_base}:sma_crossed_over")
        $redis.del("#{key_base}:sma_crossed_under")
        $redis.del("#{key_base}:atr_above_the_high")
        $redis.del("#{key_base}:atr_below_the_low")
      end

      def order_options
        @options = {
          'order' => {
            'instrument' => instrument,
            'timeInForce' => 'GTC',
            'type' => 'LIMIT',
            'positionFill' => 'DEFAULT',
            'triggerCondition' => 'MID',
            'clientExtensions' => {
              'tag' => "#{tag_order}_#{step}"
            }
          }
        }
      end

      def target_order_options
        order_options
        @options['order']['type']                    = 'LIMIT'
        @options['order']['clientExtensions']['tag'] = "#{tag_take_profit}_#{step}"
      end

      def stop_order_options
        order_options
        @options['order']['type']                    = 'STOP'
        @options['order']['clientExtensions']['tag'] = "#{tag_stop_loss}_#{step}"
      end
    end
  end
end
