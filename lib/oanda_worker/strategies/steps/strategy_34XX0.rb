# Strategy34XX0
#
#   SPAM+.
#   SPAM like strategy with incremented unit size orders.
#   Order distance determined by market volatility.
#
# To enter a trade:
#
#   Orders placed at 6AM and closed by 9AM if none triggered.
#
# To exit a trade:
#
#   Wait for take profit or stop loss to trigger.
#
module Strategies
  module Steps
    module Strategy34XX0
      # Open 3 buy and 3 sell orders at 06:00 if trend is favourable.

      # 0 Trades & 0 Orders.
      # Wait until 06:00.
      def step_1
        return false if time_outside?('06:01', '09:00', 'utc+2')
        self.close_at_entry = close
        self.initial_units  = ((calculated_units_from_balance(config[:margin], :long) || config[:units]) * initial_units_adjustment_factor).floor
        backtest_logging("close: #{close}, channel_box_size_pips: #{channel_box_size_pips}, initial_units_adjustment_factor: #{initial_units_adjustment_factor.round(round_decimal)}, max_xo_length: #{max_xo_length}")
        return true if queue_next_run
        false
      end

      # 0 Trades & 0 Orders.
      # Place 1st long order with take profit and stop loss.
      def step_2
        order_options

        order_level    = 1
        order_units    = ((calculated_units_from_balance(config[:margin], :long) || config[:units]) * initial_units_adjustment_factor).floor
        order_pips     = channel_box_size_pips * order_level
        stop_loss_pips = stop_loss_pips_from_close_at_entry - order_pips

        order_options = {
          units:            order_units,
          order_pips:       -order_pips,
          take_profit_pips: +take_profit_pips,
          stop_loss_pips:   -stop_loss_pips
        }

        create_order_at_offset!(:long, order_options) && queue_next_run ? true : false
      end

      # 0 Trades & 1 Order.
      # Place 1st short order with take profit and stop loss.
      def step_3
        order_options

        order_level    = 1
        order_units    = ((calculated_units_from_balance(config[:margin], :short) || config[:units]) * initial_units_adjustment_factor).floor
        order_pips     = channel_box_size_pips * order_level
        stop_loss_pips = stop_loss_pips_from_close_at_entry - order_pips

        order_options = {
          units:            order_units,
          order_pips:       +order_pips,
          take_profit_pips: -take_profit_pips,
          stop_loss_pips:   +stop_loss_pips
        }

        create_order_at_offset!(:short, order_options) && queue_next_run ? true : false
      end

      # 0 Trades & 2 Orders.
      # Place 2nd long order with take profit and stop loss.
      def step_4
        order_options

        order_level       = 2
        profit_loss_units = 0
        full_spread_pips  = current_candle_full_spread / pip_size

        # Sum projected profit loss at the time the new order will trigger.
        # Uses the current candle full spread as a best guess as to what the remaining half spread will be when the trade closes.
        oanda_long_orders.each do |order|
          order_take_profit_pips  = ((order['takeProfitOnFill']['price'].to_f - order['price'].to_f).round(round_decimal) / pip_size) - channel_box_size_pips
          order_take_profit_units = (order['units'].to_i.abs / take_profit_pips * (order_take_profit_pips - full_spread_pips)).round
          profit_loss_units       += order_take_profit_units
        end

        order_units    = (initial_units * order_level - profit_loss_units).floor
        order_pips     = channel_box_size_pips * order_level
        stop_loss_pips = stop_loss_pips_from_close_at_entry - order_pips

        order_options = {
          units:            order_units,
          order_pips:       -order_pips,
          take_profit_pips: +take_profit_pips,
          stop_loss_pips:   -stop_loss_pips
        }

        create_order_at_offset!(:long, order_options) && queue_next_run ? true : false
      end

      # 0 Trades & 3 Orders.
      # Place 2nd short order with take profit and stop loss.
      def step_5
        order_options

        order_level       = 2
        profit_loss_units = 0
        full_spread_pips  = current_candle_full_spread / pip_size

        # Sum projected profit loss at the time the new order will trigger.
        # Uses the current candle full spread as a best guess as to what the remaining half spread will be when the trade closes.
        oanda_short_orders.each do |order|
          order_take_profit_pips  = ((order['takeProfitOnFill']['price'].to_f - order['price'].to_f).round(round_decimal) / pip_size) + channel_box_size_pips
          order_take_profit_units = (order['units'].to_i.abs / take_profit_pips * (order_take_profit_pips + full_spread_pips)).round
          profit_loss_units       -= order_take_profit_units
        end

        order_units    = (initial_units * order_level - profit_loss_units).floor
        order_pips     = channel_box_size_pips * order_level
        stop_loss_pips = stop_loss_pips_from_close_at_entry - order_pips

        order_options = {
          units:            order_units,
          order_pips:       +order_pips,
          take_profit_pips: -take_profit_pips,
          stop_loss_pips:   +stop_loss_pips
        }

        create_order_at_offset!(:short, order_options) && queue_next_run ? true : false
      end

      # 0 Trades & 4 Orders.
      # Place 3rd long order with take profit and stop loss.
      def step_6
        order_options

        order_level       = 3
        profit_loss_units = 0
        full_spread_pips  = current_candle_full_spread / pip_size

        # Sum projected profit loss at the time the new order will trigger.
        # Uses the current candle full spread as a best guess as to what the remaining half spread will be when the trade closes.
        oanda_long_orders.each do |order|
          order_take_profit_pips  = ((order['takeProfitOnFill']['price'].to_f - order['price'].to_f).round(round_decimal) / pip_size) - channel_box_size_pips
          order_take_profit_units = (order['units'].to_i.abs / take_profit_pips * (order_take_profit_pips - full_spread_pips)).round
          profit_loss_units       += order_take_profit_units
        end

        order_units    = (initial_units * order_level - profit_loss_units).floor
        order_pips     = channel_box_size_pips * order_level
        stop_loss_pips = stop_loss_pips_from_close_at_entry - order_pips

        order_options = {
          units:            order_units,
          order_pips:       -order_pips,
          take_profit_pips: +take_profit_pips,
          stop_loss_pips:   -stop_loss_pips
        }

        create_order_at_offset!(:long, order_options) && queue_next_run ? true : false
      end

      # 0 Trades & 5 Orders.
      # Place 3rd short order with take profit and stop loss.
      def step_7
        order_options

        order_level       = 3
        profit_loss_units = 0
        full_spread_pips  = current_candle_full_spread / pip_size

        # Sum projected profit loss at the time the new order will trigger.
        # Uses the current candle full spread as a best guess as to what the remaining half spread will be when the trade closes.
        oanda_short_orders.each do |order|
          order_take_profit_pips  = ((order['takeProfitOnFill']['price'].to_f - order['price'].to_f).round(round_decimal) / pip_size) + channel_box_size_pips
          order_take_profit_units = (order['units'].to_i.abs / take_profit_pips * (order_take_profit_pips + full_spread_pips)).round
          profit_loss_units       -= order_take_profit_units
        end

        order_units    = (initial_units * order_level - profit_loss_units).floor
        order_pips     = channel_box_size_pips * order_level
        stop_loss_pips = stop_loss_pips_from_close_at_entry - order_pips

        order_options = {
          units:            order_units,
          order_pips:       +order_pips,
          take_profit_pips: -take_profit_pips,
          stop_loss_pips:   +stop_loss_pips
        }

        create_order_at_offset!(:short, order_options) && queue_next_run ? true : false
      end

      # Close orders and trades after 13:00.
      # If no trades triggered before 09:00, close all orders.
      # If 1 trade triggered before 09:00, close 3 opposite side orders.
      # If 2 trades triggered, update TP on trades 1 & 2.
      # If 3 trades triggered, update TP on trades 1, 2 & 3 and update SL on 3 trades.

      # 0 Trades & 6 Orders.
      # Wait for an order to trigger.
      def step_8
        return false if check_and_close_trades_after_exit_time!
        return false if time_outside?('06:01', '09:00', 'utc+2') && exit_orders! && wait_at_end
        return false if oanda_active_trades.any? && step_to(9) && queue_next_run
        false
      end

      # 1 Trade & 5 Orders.
      # 2 Trades & 4 Orders.
      # 3 Trades & 3 Orders.
      # Close opposite side orders.
      def step_9
        return false if check_and_close_trades_after_exit_time!
        return false if check_and_close_orders_when_trades_closed!

        if oanda_long_trades.any?
          exit_orders!(:short)
          return false if oanda_long_trades.size == 1 && step_to(10)
          return false if oanda_long_trades.size == 2 && step_to(11)
          return false if oanda_long_trades.size == 3 && step_to(13)
        end

        if oanda_short_trades.any?
          exit_orders!(:long)
          return false if oanda_short_trades.size == 1 && step_to(10)
          return false if oanda_short_trades.size == 2 && step_to(11)
          return false if oanda_short_trades.size == 3 && step_to(13)
        end

        false
      end

      # 1 Trade & 2 Orders.
      # Wait for trade 2 or 3 to trigger before carrying on.
      def step_10
        return false if check_and_close_trades_after_exit_time!
        return false if check_and_close_orders_when_trades_closed!
        return false if oanda_active_trades.size == 2 && step_to(11) && queue_next_run
        return false if oanda_active_trades.size == 3 && step_to(13) && queue_next_run
        false
      end

      # 2 Trades & 1 Order.
      # Trade 2 triggered, update TPs.
      def step_11
        return false if check_and_close_trades_after_exit_time!
        return false if check_and_close_orders_when_trades_closed!
        return false if update_take_profit_prices! && step_to(12)
        false
      end

      # 2 Trades & 1 Order.
      # Wait for trade 3 to trigger before carrying on.
      def step_12
        return false if check_and_close_trades_after_exit_time!
        return false if check_and_close_orders_when_trades_closed!
        return false if oanda_active_trades.size == 3 && step_to(13) && queue_next_run
        false
      end

      # 3 Trades & 0 Orders.
      # Trade 3 triggered, update TPs.
      def step_13
        return false if check_and_close_trades_after_exit_time!
        return false if check_and_close_orders_when_trades_closed!
        return false if update_take_profit_prices! && step_to(14)
        false
      end

      # 0 Trades & 0 Orders.
      # Wait until 13:00 before resetting the strategy for the next day.
      def step_14
        return false if time_outside?('06:01', '13:00', 'utc+2') && exit_trades_and_orders! && cleanup && reset_steps
        false
      end

      private

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

      def initial_units_adjustment_factor
        @initial_units_adjustment_factor ||= initial_units_channel_base.to_f / max_xo_length.to_f
      end

      def check_and_close_trades_after_exit_time!
        time_outside?('06:01', '13:00', 'utc+2') && exit_trades_and_orders! && wait_at_end
      end

      def check_and_close_orders_when_trades_closed!
        oanda_active_trades.empty? && exit_orders! && wait_at_end
      end

      # Update take profit prices on all trades to match the latest trade's take profit price.
      def update_take_profit_prices!
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
        end

        true
      end

      def wait_at_end
        cleanup && step_to(14)
      end

      def channel_box_size_pips
        @channel_box_size_pips ||= channel_box_size_base * (max_xo_length + (max_xo_length - channel_box_size_median))
      end

      def take_profit_pips
        @take_profit_pips ||= take_profit_box_size_base * max_xo_length
      end

      def stop_loss_pips_from_close_at_entry
        @stop_loss_pips_from_close_at_entry ||= stop_loss_box_size_base * channel_box_size_pips
      end

      def max_xo_length
        @max_xo_length ||= indicator_pf_a['data'].map{ |point| point['attributes']['xo_length'] }.max
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

      def initial_units
        $redis.get("#{key_base}:initial_units") && $redis.get("#{key_base}:initial_units").to_i
      end

      def initial_units=(value)
        $redis.set("#{key_base}:initial_units", value.to_i.abs)
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

      def cleanup
        super
        $redis.del("#{key_base}:initial_units")
      end
    end
  end
end
