# Only kept here for reference to the target limit orders instead of take profit orders.
# This will need to be completely rewritten to fit the current Strategy24XX0.
#
# Strategy24XX1
#
#   Waterfall.
#   Using target limit orders for take profits.
#
# To enter a trade:
#
#   When 3 consecutive lower candle towers move downwards toward the waterfall moving averages, and touches the waterfall but does not close beyond,
#   a long order is placed on the lowest high of the candle tower.
#   When 3 consecutive higher candle towers move upwards toward the waterfall moving averages, and touches the waterfall but does not close beyond,
#   a short order is placed on the highest low of the candle tower.
#
# To exit a trade:
#
#   Wait for a take profit to trigger.
#   Wait for stop loss or until exit time.
#
module Strategies
  module Steps
    module Strategy24XX1
      attr_reader :ema_leading, :ema_lagging, :atr, :ema_leading_count, :ema_lagging_count,
                  :take_profit_pips, :stop_loss_pips, :break_even_pips, :protective_stop_loss_pips,
                  :targets, :stops, :break_evens, :protective_stops, :max_spread, :trading_days, :trading_times,
                  :stop_loss_mode, :stop_loss_factor, :stop_loss_buffer,
                  :take_profit_mode, :take_profit_factor, :take_profit_buffer,
                  :break_even_mode, :break_even_buffer,
                  :protective_stop_loss_mode

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
        end

        # Patterns!
        if [1, 2].include?(step)
          @ema_leading = Overlays::ExponentialMovingAverage.new(candles: candles, count: ema_leading_count).points
          @ema_lagging = Overlays::ExponentialMovingAverage.new(candles: candles, count: ema_lagging_count).points
        end

        # Orders!
        if [1].include?(step)
          @stop_loss_pips =
            case stop_loss_mode
            when :none
              nil
            when :manual
              stops[0]
            when :atr
              atr = Indicators::AverageTrueRange.new(candles: candles, count: stops[0]).point
              atr / pip_size
            when :previous_candles
              0 # Calculated later.
            end

          @take_profit_pips =
            case take_profit_mode
            when :none
              nil
            when :manual
              targets[0]
            when :atr
              atr = Indicators::AverageTrueRange.new(candles: candles, count: targets[0]).point
              atr / pip_size
            when :stop_loss_percent
              0 # Calculated later.
            end
        end

        # Trades!
        if [3, 4].include?(step)
          @break_even_pips =
            case break_even_mode
            when :none
              nil
            when :manual
              break_evens[0]
            when :atr
              atr = Indicators::AverageTrueRange.new(candles: candles, count: break_evens[0]).point
              (atr / pip_size) * break_evens[1]
            when :take_profit_percent
              0 # Calculated later.
            end

          @protective_stop_loss_pips =
            case protective_stop_loss_mode
            when :none
              nil
            when :candle_trailing_stop
              0 # Calculated later.
            when :trailing_stop_manual
              protective_stops[0]
            when :trailing_stop_atr
              atr = Indicators::AverageTrueRange.new(candles: candles, count: protective_stops[0]).point
              (atr / pip_size) * protective_stops[1]
            when :trailing_stop_take_profit_percent
              0 # Calculated later.
            end
        end

        raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1
        return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && backtest_export && cleanup && reset_steps
      end

      # Patterns!
      # Wait for first pattern.
      # Place first order with stop loss.

      # 0 Trades & 0 Orders.
      # Wait for trigger condition and place order.
      def step_1
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(2) && queue_next_run

        return false unless trading_days.include?(week_day) && times_inside?(trading_times)
        return false unless acceptable_spread?(max_spread)

        if create_long_order?
          return false if create_long_entry_order! && step_to(2) && queue_next_run
        end

        if create_short_order?
          return false if create_short_entry_order! && step_to(2) && queue_next_run
        end

        false
      end

      # Orders!
      # Wait for an order to be triggered and place target orders.
      # Wait for a pattern to be invalidated and remove the order.
      # Move entry order when tower continues in one direction.
      # Make sure the current valid patterns match the current orders.

      # 0 Trades, 1 Bullish or Bearish Order.
      # Wait for a bullish or bearish order to trigger.
      # Cancel order if the bullish or bearish pattern was invalidated.
      # Cancel order if bullish or bearish pattern does not match the current orders respectively.
      def step_2
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && reset_steps && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(4) && queue_next_run

        if oanda_long_orders.any?
          return false if pattern_invalid?(:long) && exit_orders!(:long) && reset_steps
          return false if move_order_price?(:long) && exit_orders!(:long) && reset_steps && queue_next_run
        end

        if oanda_short_orders.any?
          return false if pattern_invalid?(:short) && exit_orders!(:short) && reset_steps
          return false if move_order_price?(:short) && exit_orders!(:short) && reset_steps && queue_next_run
        end

        false
      end

      # Targets!
      # Place target orders.

      # 1 Trade & 0 Orders.
      # Place target order.
      # If order immediately gets filled when created, we need to reset steps.
      def step_3
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && reset_steps && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(4) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(5) && queue_next_run

        if oanda_long_trades.any?
          if create_short_target_order!(oanda_long_trades.last)
            return false if step_to(4) && queue_next_run
          else
            return false if oanda_order['orderFillTransaction'] && oanda_order['orderFillTransaction']['tradesClosed'] && step_to(5) && queue_next_run
          end
        end

        if oanda_short_trades.any?
          if create_long_target_order!(oanda_short_trades.last)
            return false if step_to(4) && queue_next_run
          else
            return false if oanda_order['orderFillTransaction'] && oanda_order['orderFillTransaction']['tradesClosed'] && step_to(5) && queue_next_run
          end
        end

        false
      end

      # Trades!
      # Wait for trade to exit.

      # 1 Trade & 1 Target Order.
      # Wait for stop loss to trigger.
      # Wait for target to trigger.
      def step_4
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && reset_steps && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(5) && queue_next_run
        false
      end

      # 0 Trades & 1+ Target Order.
      # Cancel remaining orders.
      # Reset steps.
      def step_5
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(4) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run

        return false if exit_trades_and_orders! && backtest_export && reset_steps && queue_next_run

        false
      end

      private

      def create_long_order?
        bearish_tower? && bearish_tower_touches_waterfall? && bearish_tower_does_not_close_beyond_waterfall? && waterfall_wide_enough?
      end

      def create_short_order?
        bullish_tower? && bullish_tower_touches_waterfall? && bullish_tower_does_not_close_beyond_waterfall? && waterfall_wide_enough?
      end

      def pattern_invalid?(type)
        case type
        when :long
          !create_long_order?
        when :short
          !create_short_order?
        end
      end

      def move_order_price?(type)
        case type
        when :long
          candles['candles'][-1]['mid']['h'].to_f < oanda_long_orders.last['price'].to_f
        when :short
          candles['candles'][-1]['mid']['l'].to_f > oanda_short_orders.last['price'].to_f
        end
      end

      def bullish_tower?
        return candles['candles'][-1]['mid']['l'].to_f > candles['candles'][-2]['mid']['l'].to_f && candles['candles'][-2]['mid']['l'].to_f > candles['candles'][-3]['mid']['l'].to_f
      end

      def bearish_tower?
        return candles['candles'][-1]['mid']['h'].to_f < candles['candles'][-2]['mid']['h'].to_f && candles['candles'][-2]['mid']['h'].to_f < candles['candles'][-3]['mid']['h'].to_f
      end

      def bullish_tower_touches_waterfall?
        candles['candles'][-1]['mid']['h'].to_f >= [ema_leading[-1], ema_lagging[-1]].min
      end

      def bearish_tower_touches_waterfall?
        candles['candles'][-1]['mid']['l'].to_f <= [ema_leading[-1], ema_lagging[-1]].max
      end

      def bullish_tower_close_beyond_waterfall?
        candles['candles'][-1]['mid']['c'].to_f >= [ema_leading[-1], ema_lagging[-1]].max ||
        candles['candles'][-2]['mid']['c'].to_f >= [ema_leading[-2], ema_lagging[-2]].max ||
        candles['candles'][-3]['mid']['c'].to_f >= [ema_leading[-3], ema_lagging[-3]].max
      end

      def bearish_tower_close_beyond_waterfall?
        candles['candles'][-1]['mid']['c'].to_f <= [ema_leading[-1], ema_lagging[-1]].min ||
        candles['candles'][-2]['mid']['c'].to_f <= [ema_leading[-2], ema_lagging[-2]].min ||
        candles['candles'][-3]['mid']['c'].to_f <= [ema_leading[-3], ema_lagging[-3]].min
      end

      def bullish_tower_does_not_close_beyond_waterfall?
        !bullish_tower_close_beyond_waterfall?
      end

      def bearish_tower_does_not_close_beyond_waterfall?
        !bearish_tower_close_beyond_waterfall?
      end

      def waterfall_wide_enough?
        true
      end

      def units(type)
        (calculated_units_from_balance(config[:margin], type) || config[:units]).floor
      end

      def entry_price(type)
        case type
        when :long
          candles['candles'][-1]['mid']['h'].to_f
        when :short
          candles['candles'][-1]['mid']['l'].to_f
        end
      end

      def stop_loss_price(type)
        case type
        when :long
          [candles['candles'][-1]['mid']['l'].to_f, candles['candles'][-2]['mid']['l'].to_f, candles['candles'][-3]['mid']['l'].to_f].min - stop_loss_pips * pip_size
        when :short
          [candles['candles'][-1]['mid']['h'].to_f, candles['candles'][-2]['mid']['h'].to_f, candles['candles'][-3]['mid']['h'].to_f].max + stop_loss_pips * pip_size
        end
      end

      def take_profit_price(type, trade)
        case type
        when :long
          trade['price'].to_f + take_profit_pips * pip_size
        when :short
          trade['price'].to_f - take_profit_pips * pip_size
        end
      end

      def create_long_entry_order!
        order_options

        order_units     = units(:long)
        order_price     = entry_price(:long)
        stop_loss_price = stop_loss_price(:long)

        candles(smooth: true, include_incomplete_candles: true, refresh: true)
        return false if current_candle['mid']['c'].to_f > order_price

        order_options = {
          order_price:     order_price.round(round_decimal),
          stop_loss_price: stop_loss_price.round(round_decimal),
          units:           order_units
        }

        create_long_order!(order_options)
      end

      def create_short_entry_order!
        order_options

        order_units     = units(:short)
        order_price     = entry_price(:short)
        stop_loss_price = stop_loss_price(:short)

        candles(smooth: true, include_incomplete_candles: true, refresh: true)
        return false if current_candle['mid']['c'].to_f < order_price

        order_options = {
          order_price:     order_price.round(round_decimal),
          stop_loss_price: stop_loss_price.round(round_decimal),
          units:           order_units
        }

        create_short_order!(order_options)
      end

      def create_long_target_order!(trade)
        target_order_options

        order_units = units(:short)
        order_price = take_profit_price(:short, trade)

        order_options = {
          order_price: order_price.round(round_decimal),
          units:       order_units
        }

        create_long_order!(order_options)
      end

      def create_short_target_order!(trade)
        target_order_options

        order_units = units(:long)
        order_price = take_profit_price(:long, trade)

        order_options = {
          order_price: order_price.round(round_decimal),
          units:       order_units
        }

        create_short_order!(order_options)
      end

      def backtest_export
        trade, entry_date, entry_time, exit_date, exit_time, target_prices, pos_exit_prices, pos_total_spreads = *super
        return true unless backtesting? && trade

        green_line       = '#93c47d'
        green_background = '#d9ead3'
        red_line         = '#e06666'
        red_background   = '#f4cccc'
        type             = trade['initialUnits'].to_i >= 0 ? :long : :short

        entry_price  = trade['price']
        exit_price   = trade['averageClosePrice']

        profit_loss =
          case type
          when :long
            exit_price >= entry_price ? :profit : :loss
          when :short
            exit_price <= entry_price ? :profit : :loss
          end

        # Icons.
        # 0xf057 = 61527 - circle cross
        # 0xf058 = 61528 - circle check
        # 0xf0a8 = 61608 - left circle arrow
        # 0xf0a9 = 61609 - right circle arrow
        # 0xf0aa = 61610 - up circle arrow
        # 0xf0ab = 61611 - down circle arrow
        # 0xf062 = 61538 - up arrow
        # 0xf063 = 61539 - down arrow

        # Export to ; delimited file for import into TradingView Charts.

        exit_shape   = 'icon'
        entry_shape  = 'icon'
        line_shape   = 'trend_line'

        case type
        when :long
          entry_icon = 61610
        when :short
          entry_icon = 61611
        end

        case profit_loss
        when :profit
          entry_color = green_line
          exit_color  = green_line
          exit_icon   = 61528
        when :loss
          entry_color = red_line
          exit_color  = red_line
          exit_icon   = 61527
        end

        entry_points = [{ time: Time.parse("#{entry_date} #{entry_time}").to_i, price: entry_price.to_s }]
        exit_points  = [{ time: Time.parse("#{exit_date} #{exit_time}").to_i, price: exit_price.to_s }]
        line_points  = [
          { time: Time.parse("#{entry_date} #{entry_time}").to_i, price: entry_price.to_s },
          { time: Time.parse("#{exit_date} #{exit_time}").to_i, price: exit_price.to_s }
        ]

        entry_overrides = {
          icon:  entry_icon,
          color: entry_color,
          size:  25,
          scale: 1
        }

        exit_overrides = {
          icon:  exit_icon,
          color: exit_color,
          size:  25,
          scale: 1
        }

        line_overrides = {
          textcolor:      exit_color,
          linecolor:      exit_color,
          linestyle:      1,
          linewidth:      2,
          showPriceRange: true,
          showBarsRange:  true
        }

        entry_chart_values = {
          text:      nil,
          shape:     entry_shape,
          points:    entry_points.to_json,
          overrides: entry_overrides.to_json,
          zorder:    'top'
        }

        exit_chart_values = {
          text:      nil,
          shape:     exit_shape,
          points:    exit_points.to_json,
          overrides: exit_overrides.to_json,
          zorder:    'top'
        }

        line_chart_values = {
          text:      nil,
          shape:     line_shape,
          points:    line_points.to_json,
          overrides: line_overrides.to_json,
          zorder:    'top'
        }

        backtest_chart_plotting(entry_chart_values)
        backtest_chart_plotting(exit_chart_values)
        backtest_chart_plotting(line_chart_values)

        true
      end

      def cleanup
        super
        # $redis.del("#{key_base}:bullish_pattern")
        # $redis.del("#{key_base}:bearish_pattern")
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
    end
  end
end
