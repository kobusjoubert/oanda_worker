module Strategies
  module Steps
    module StrategyML
      def step_1
        return true if self.oanda_trade = oanda_last_trade
        candles(count: prediction_candles_required)

        if last_prediction_requested_at
          begin
            prediction_interval_candle_time = Time.parse(candles['candles'][-prediction_interval_on_entry]['time']).utc
          rescue ArgumentError, TypeError
            prediction_interval_candle_time = Time.at(candles['candles'][-prediction_interval_on_entry]['time'].to_i).utc
          end

          return false if prediction_interval_candle_time < last_prediction_requested_at
        end

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

        if enter_long?
          publish_prediction_values # TODO: Remove once done with testing.

          if create_long_order!
            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f + take_profit).round(round_decimal),
              stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f - stop_loss).round(round_decimal)
            }
            update_trade!(options)
            return true
          end
        end

        if enter_short?
          publish_prediction_values # TODO: Remove once done with testing.

          if create_short_order!
            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f - take_profit).round(round_decimal),
              stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f + stop_loss).round(round_decimal)
            }
            update_trade!(options)
            return true
          end
        end

        false
      end

      def step_2
        return true unless self.oanda_trade = oanda_last_trade
        candles(count: prediction_candles_required)

        begin
          prediction_interval_candle_time = Time.parse(candles['candles'][-prediction_interval_on_exit]['time']).utc
        rescue ArgumentError, TypeError
          prediction_interval_candle_time = Time.at(candles['candles'][-prediction_interval_on_exit]['time'].to_i).utc
        end

        return false if prediction_interval_candle_time < last_prediction_requested_at

        # TODO: Update take profit and stop loss!

        if self.send("exit_#{oanda_trade_type}?")
          publish_prediction_values # TODO: Remove once done with testing.
          return exit_trade!
        end

        false
      end

      private

      def enter_long?
        prediction > candles['candles'][-1]['mid']['c'].to_f + pips_required
      end

      def enter_short?
        prediction < candles['candles'][-1]['mid']['c'].to_f - pips_required
      end

      def exit_long?
        prediction < last_prediction
      end

      def exit_short?
        prediction > last_prediction
      end
    end
  end
end
