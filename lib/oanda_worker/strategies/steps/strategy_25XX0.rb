# Strategy25XX0
#
#   Waterfall Labouchère.
#   Using take profit on fill for take profits.
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
    module Strategy25XX0
      attr_reader :ema_leading, :ema_lagging, :atr, :ema_leading_count, :ema_lagging_count,
                  :initial_units_list, :max_units_factor,
                  :take_profit_pips, :stop_loss_pips, :break_even_pips, :protective_stop_loss_pips,
                  :targets, :stops, :risk_pips, :break_evens, :protective_stops, :max_spread, :trading_times,
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

        initialize_units_list if units_list.empty?

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

      # 0 Trades & 0 Orders.
      # Wait for trigger condition and place order with stop loss and take profit.
      def step_1
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(2) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(5) && queue_next_run

        return false unless day_and_time_inside?(trading_times)
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

      # 0 Trades, 1 Bullish or Bearish Order.
      # Wait for an order to be triggered.
      # Wait for a pattern to be invalidated and remove the order.
      # Move entry order when tower continues in one direction.
      # Make sure the current valid patterns match the current orders.
      def step_2
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && reset_steps && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(5) && queue_next_run

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

      # Trades!

      # 1 Trade & 0 Orders.
      # Wait for stop loss to trigger.
      # Wait for take profit to trigger.
      # Monitor price to roll stop to break even.
      def step_3
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && update_units_list && reset_steps && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(5) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(6) && queue_next_run

        return false if break_even_mode == :none && step_to(4) && queue_next_run

        if move_stop_to_break_even?
          return false if roll_stop_to_break_even! && step_to(4) && queue_next_run
        end

        false
      end

      # 1 Trade & 0 Orders.
      # Wait for stop loss to trigger.
      # Wait for take profit to trigger.
      # Monitor price to trail stop after break even.
      def step_4
        return false if oanda_active_trades.empty? && oanda_active_orders.empty? && backtest_export && update_units_list && reset_steps && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.any? && step_to(5) && queue_next_run
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(6) && queue_next_run

        if move_trailing_stop?
          return false if move_trailing_stop!
        end

        false
      end

      # 1 Trade & 1 Order.
      # This should not happen.
      def step_5
        return false if step_to(6) && queue_next_run
        false
      end

      # 0+ Trades & 0+ Orders.
      # Cancel remaining trades and orders.
      # Reset steps.
      def step_6
        return false if oanda_active_trades.empty? && oanda_active_orders.any? && step_to(2) && queue_next_run
        return false if oanda_active_trades.any? && oanda_active_orders.empty? && step_to(3) && queue_next_run

        return false if exit_trades_and_orders! && backtest_export && update_units_list && reset_steps && queue_next_run
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

      def move_stop_to_break_even?
        return false if break_even_mode == :none

        trade                           = oanda_active_trades.last
        entry_price                     = trade['price'].to_f
        take_profit_price               = trade['takeProfitOrder']['price'].to_f
        current_pip_distance_from_entry = (entry_price - current_candle['mid']['c'].to_f).abs / pip_size
        calculated_break_even_pips      = break_even_pips

        if [:take_profit_percent].include?(break_even_mode)
          calculated_break_even_pips = ((entry_price - take_profit_price).abs / pip_size) * (break_evens[0] / 100.to_f)
        end

        current_pip_distance_from_entry >= calculated_break_even_pips
      end

      def move_trailing_stop?
        return false if protective_stop_loss_mode == :none

        trade               = oanda_active_trades.last
        type                = trade['initialUnits'].to_i >= 0 ? :long : :short
        entry_price         = trade['price'].to_f
        take_profit_price   = trade['takeProfitOrder']['price'].to_f
        stop_loss_price     = trade['stopLossOrder']['price'].to_f
        new_stop_loss_price = trailing_stop_loss_price(type, entry_price, take_profit_price)

        case type
        when :long
          new_stop_loss_price > stop_loss_price
        when :short
          new_stop_loss_price < stop_loss_price
        end
      end

      def bullish_tower?
        candles['candles'][-1]['mid']['l'].to_f > candles['candles'][-2]['mid']['l'].to_f && candles['candles'][-2]['mid']['l'].to_f > candles['candles'][-3]['mid']['l'].to_f &&
        candles['candles'][-2]['mid']['h'].to_f > candles['candles'][-3]['mid']['h'].to_f
      end

      def bearish_tower?
        candles['candles'][-1]['mid']['h'].to_f < candles['candles'][-2]['mid']['h'].to_f && candles['candles'][-2]['mid']['h'].to_f < candles['candles'][-3]['mid']['h'].to_f &&
        candles['candles'][-2]['mid']['l'].to_f < candles['candles'][-3]['mid']['l'].to_f
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
        units_factor = units_list.one? ? units_list.last : units_list.first + units_list.last

        while units_factor >= max_units_factor
          units_list_dilute_last_value
          units_factor = units_list.one? ? units_list.last : units_list.first + units_list.last
        end

        (config[:units] / max_units_factor.to_f * units_factor.to_f).floor
      end

      def entry_price(type)
        case type
        when :long
          candles['candles'][-1]['mid']['h'].to_f
        when :short
          candles['candles'][-1]['mid']['l'].to_f
        end
      end

      def stop_loss_price(type, entry_price)
        calculated_stop_loss_pips = stop_loss_pips

        case type
        when :long
          if [:previous_candles].include?(stop_loss_mode)
            lowest_low                = candles['candles'].last(stops[0]).map{ |candle| candle['mid']['l'].to_f }.min
            calculated_stop_loss_pips = (entry_price - lowest_low) / pip_size
          end

          calculated_stop_loss_pips = calculated_stop_loss_pips * stop_loss_factor + stop_loss_buffer
          calculated_stop_loss_pips = risk_pips if calculated_stop_loss_pips > risk_pips

          return (entry_price - (calculated_stop_loss_pips * pip_size)).round(round_decimal)
        when :short
          if [:previous_candles].include?(stop_loss_mode)
            highest_high              = candles['candles'].last(stops[0]).map{ |candle| candle['mid']['h'].to_f }.max
            calculated_stop_loss_pips = (highest_high - entry_price) / pip_size
          end

          calculated_stop_loss_pips = calculated_stop_loss_pips * stop_loss_factor + stop_loss_buffer
          calculated_stop_loss_pips = risk_pips if calculated_stop_loss_pips > risk_pips

          return (entry_price + (calculated_stop_loss_pips * pip_size)).round(round_decimal)
        end
      end

      def trailing_stop_loss_price(type, entry_price, take_profit_price)
        calculated_stop_loss_pips       = protective_stop_loss_pips
        current_pip_distance_from_entry = (current_candle['mid']['c'].to_f - entry_price) / pip_size

        case type
        when :long
          if [:candle_trailing_stop].include?(protective_stop_loss_mode)
            lowest_low = candles['candles'].last(protective_stops[0]).map{ |candle| candle['mid']['l'].to_f }.min
            calculated_stop_loss_pips = (lowest_low - entry_price) / pip_size
          end

          if [:trailing_stop_manual, :trailing_stop_atr].include?(protective_stop_loss_mode)
            calculated_stop_loss_pips = current_pip_distance_from_entry - protective_stop_loss_pips
          end
        when :short
          if [:candle_trailing_stop].include?(protective_stop_loss_mode)
            highest_high = candles['candles'].last(stops[0]).map{ |candle| candle['mid']['h'].to_f }.max
            calculated_stop_loss_pips = (highest_high - entry_price) / pip_size
          end

          if [:trailing_stop_manual, :trailing_stop_atr].include?(protective_stop_loss_mode)
            calculated_stop_loss_pips = current_pip_distance_from_entry + protective_stop_loss_pips
          end
        end

        if [:trailing_stop_take_profit_percent].include?(protective_stop_loss_mode)
          calculated_stop_loss_pips = ((take_profit_price - entry_price) / pip_size) * (protective_stops[0] / 100.to_f)
        end

        calculated_stop_loss_pips = risk_pips if calculated_stop_loss_pips > risk_pips
        (entry_price + (calculated_stop_loss_pips * pip_size)).round(round_decimal)
      end

      def take_profit_price(type, entry_price, stop_loss_price)
        calculated_take_profit_pips = take_profit_pips

        if [:stop_loss_percent].include?(take_profit_mode)
          calculated_take_profit_pips = ((entry_price - stop_loss_price).abs / pip_size) * (targets[0] / 100.to_f)
        end

        case type
        when :long
          return (entry_price + ((calculated_take_profit_pips * take_profit_factor + take_profit_buffer) * pip_size)).round(round_decimal)
        when :short
          return (entry_price - ((calculated_take_profit_pips * take_profit_factor + take_profit_buffer) * pip_size)).round(round_decimal)
        end
      end

      def create_long_entry_order!
        order_options

        order_units       = units(:long)
        order_price       = entry_price(:long)
        stop_loss_price   = stop_loss_price(:long, order_price)
        take_profit_price = take_profit_price(:long, order_price, stop_loss_price)

        candles(smooth: true, include_incomplete_candles: true, refresh: true)
        return false if current_candle['mid']['c'].to_f > order_price

        self.pattern = {
          pattern:           :waterfall,
          initial_stop_loss: stop_loss_price,
          pattern_pips:      ((ema_leading[-1] - ema_lagging[-1]).abs / pip_size).round(1),
          candle_spread:     current_candle_full_spread_in_pips
        }

        order_options = {
          order_price:       order_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          units:             order_units
        }

        create_long_order!(order_options)
      end

      def create_short_entry_order!
        order_options

        order_units       = units(:short)
        order_price       = entry_price(:short)
        stop_loss_price   = stop_loss_price(:short, order_price)
        take_profit_price = take_profit_price(:short, order_price, stop_loss_price)

        candles(smooth: true, include_incomplete_candles: true, refresh: true)
        return false if current_candle['mid']['c'].to_f < order_price

        self.pattern = {
          pattern:           :waterfall,
          initial_stop_loss: stop_loss_price,
          pattern_pips:      ((ema_leading[-1] - ema_lagging[-1]).abs / pip_size).round(1),
          candle_spread:     current_candle_full_spread_in_pips
        }

        order_options = {
          order_price:       order_price.round(round_decimal),
          stop_loss_price:   stop_loss_price.round(round_decimal),
          take_profit_price: take_profit_price.round(round_decimal),
          units:             order_units
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

      def roll_stop_to_break_even!
        trade = oanda_active_trades.last
        type  = trade['initialUnits'].to_i >= 0 ? :long : :short

        new_stop_loss_price =
          case type
          when :long
            trade['price'].to_f + (break_even_buffer * pip_size)
          when :short
            trade['price'].to_f - (break_even_buffer * pip_size)
          end

        candles(smooth: true, include_incomplete_candles: true, refresh: true)

        case type
        when :long
          return false if current_candle['mid']['c'].to_f < new_stop_loss_price
        when :short
          return false if current_candle['mid']['c'].to_f > new_stop_loss_price
        end

        unless trade['stopLossOrder']['price'].to_f == new_stop_loss_price
          options = {
            id:        trade['id'],
            stop_loss: new_stop_loss_price.round(round_decimal)
          }

          return true if update_trade!(options)
        end

        false
      end

      def move_trailing_stop!
        trade               = oanda_active_trades.last
        type                = trade['initialUnits'].to_i >= 0 ? :long : :short
        entry_price         = trade['price'].to_f
        take_profit_price   = trade['takeProfitOrder']['price'].to_f
        new_stop_loss_price = trailing_stop_loss_price(type, entry_price, take_profit_price)

        candles(smooth: true, include_incomplete_candles: true, refresh: true)

        case type
        when :long
          return false if current_candle['mid']['c'].to_f < new_stop_loss_price
        when :short
          return false if current_candle['mid']['c'].to_f > new_stop_loss_price
        end

        unless trade['stopLossOrder']['price'].to_f == new_stop_loss_price
          options = {
            id:        trade['id'],
            stop_loss: new_stop_loss_price.round(round_decimal)
          }

          return true if update_trade!(options)
        end

        false
      end

      def pattern
        JSON.parse($redis.get("#{key_base}:pattern")).symbolize_keys
      end

      def pattern=(value)
        $redis.set("#{key_base}:pattern", value.to_json)
      end

      def units_list
        $redis.lrange("#{key_base}:units_list", 0, -1).map(&:to_i).sort
      end

      def units_list_push(value)
        $redis.rpush("#{key_base}:units_list", value.to_i)
        sorted_units_list = units_list
        $redis.del("#{key_base}:units_list")

        sorted_units_list.each do |value|
          $redis.rpush("#{key_base}:units_list", value.to_i)
        end
      end

      def units_list_remove_first_and_last
        $redis.rpop("#{key_base}:units_list")
        $redis.lpop("#{key_base}:units_list")
      end

      def units_list_dilute_last_value
        last_value = $redis.rpop("#{key_base}:units_list")
        last_value = last_value.to_f
        new_value_1 = (last_value / 2).floor
        new_value_2 = last_value - new_value_1
        units_list_push(new_value_1)
        units_list_push(new_value_2)
      end

      def initialize_units_list
        $redis.del("#{key_base}:units_list")

        initial_units_list.each do |value|
          $redis.rpush("#{key_base}:units_list", value.to_i)
        end
      end

      def update_units_list
        trade = oanda_changes['changes']['tradesClosed'].last

        if trade['stopLossOrder']['state'] == 'FILLED'
          units_factor = units_list.one? ? units_list.last : units_list.first + units_list.last
          units_list_push(units_factor)
        end

        if trade['takeProfitOrder']['state'] == 'FILLED'
          units_list_remove_first_and_last
        end

        true
      end

      def backtest_export
        trade, entry_date, entry_time, exit_date, exit_time, target_prices, pos_exit_prices, pos_total_spreads = *super
        return true unless backtesting? && trade

        type         = trade['initialUnits'].to_i >= 0 ? :long : :short
        entry_price  = trade['price'].to_f
        exit_price   = trade['averageClosePrice'].to_f

        profit_loss =
          case type
          when :long
            exit_price >= entry_price ? :profit : :loss
          when :short
            exit_price <= entry_price ? :profit : :loss
          end

        # Export to tab delimited file for import into Google Sheets.

        targets_count = 1

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
          pos_2_total_spread:   targets_count > 1 ? pos_total_spreads[1] || pos_total_spreads[0] : nil
        }

        sheet_values.merge!(pattern.select!{ |key, _| ![:pattern].include?(key) })

        backtest_exporting(sheet_values)

        # Export to ; delimited file for import into TradingView Charts.

        # Icons.
        # 0xf057 = 61527 - circle cross
        # 0xf058 = 61528 - circle check
        # 0xf0a8 = 61608 - left circle arrow
        # 0xf0a9 = 61609 - right circle arrow
        # 0xf0aa = 61610 - up circle arrow
        # 0xf0ab = 61611 - down circle arrow
        # 0xf062 = 61538 - up arrow
        # 0xf063 = 61539 - down arrow

        green_line       = '#93c47d'
        green_background = '#d9ead3'
        red_line         = '#e06666'
        red_background   = '#f4cccc'

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

        entry_date_time = Time.parse("#{entry_date} #{entry_time}").to_i - config[:chart_interval]
        exit_date_time  = Time.parse("#{exit_date} #{exit_time}").to_i - config[:chart_interval]

        entry_points = [{ time: entry_date_time, price: entry_price }]
        exit_points  = [{ time: exit_date_time, price: exit_price }]
        line_points  = [
          { time: entry_date_time, price: entry_price },
          { time: exit_date_time, price: exit_price }
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
        $redis.del("#{key_base}:pattern")
        # $redis.del("#{key_base}:units_list") # Do not clean out units_list, it is used again in step 1.
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
