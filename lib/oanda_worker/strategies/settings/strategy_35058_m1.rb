module Strategies
  module Settings
    module Strategy35058M1
      def settings!
        # Max stop loss pips to risk.
        @risk_pips = 150.freeze

        # H1 = 1
        # M5 = 12
        # M1 = 60
        @highest_high_lowest_low_candles_count = 60.freeze
        @minutes_allowed_to_place_orders       = 5.freeze

        # Max acceptable spread in pips before halting the strategy.
        @max_spread = 8.freeze

        # Stop loss modes.
        # :none, :manual, :atr, :previous_candles
        @stop_loss_mode   = :manual
        @stop_loss_factor = 1.freeze # Multiply calculated stop losses.
        @stop_loss_buffer = 0.freeze # Pad calculated stop losses with pips.

        # Take profit modes.
        # :none, :manual, :atr, :stop_loss_percent
        @take_profit_mode   = :stop_loss_percent
        @take_profit_factor = 1.freeze # Multiply calculated take profits.
        @take_profit_buffer = 0.freeze # Pad calculated take profits with pips.

        # Break even modes.
        # :none, :manual, :atr, :take_profit_percent
        @break_even_mode   = :none
        @break_even_buffer = 5.freeze # Additional pips to secure when moving stop to break even.

        # Protective stop loss modes.
        # :none, :candle_trailing_stop, :trailing_stop_manual, :trailing_stop_atr, :trailing_stop_take_profit_percent, :jumping_stop_manual, :jumping_stop_atr, :jumping_stop_take_profit_percent
        @protective_stop_loss_mode = :none

        stop_loss_values = {
          none:             nil,
          manual:           [15],
          atr:              [20],
          previous_candles: [15]
        }

        take_profit_values = {
          none:              nil,
          manual:            [35],
          atr:               [20],
          stop_loss_percent: [100]
        }

        break_even_values = {
          none:                nil,
          manual:              [25],
          atr:                 [20, 1],
          take_profit_percent: [20]
        }

        protective_stop_loss_values = {
          none:                              nil,
          candle_trailing_stop:              [15],
          trailing_stop_manual:              [30],
          trailing_stop_atr:                 [20, 2],
          trailing_stop_take_profit_percent: [20],
          jumping_stop_manual:               [25],
          jumping_stop_atr:                  [20, 2],
          jumping_stop_take_profit_percent:  [20]
        }

        @stops            = stop_loss_values[stop_loss_mode].freeze
        @targets          = take_profit_values[take_profit_mode].freeze
        @break_evens      = break_even_values[break_even_mode].freeze
        @protective_stops = protective_stop_loss_values[protective_stop_loss_mode].freeze

        @trading_times = {
          mon: [['14:00', '15:00']],
          tue: [['14:00', '15:00']],
          wed: [['14:00', '15:00']],
          thu: [['14:00', '15:00']],
          fri: [['14:00', '15:00']]
        }.freeze

        true
      end
    end
  end
end
