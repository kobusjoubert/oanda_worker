module Strategies
  module Settings
    module Strategy24028H1
      def settings!
        # Max stop loss pips to risk.
        @risk_pips = 150.freeze

        # Moving averages.
        @ema_leading_count = 9.freeze
        @ema_lagging_count = 19.freeze

        # Max acceptable spread in pips before halting the strategy.
        @max_spread = 8.freeze

        # Stop loss modes.
        # :none, :manual, :atr, :previous_candles
        @stop_loss_mode   = :atr
        @stop_loss_factor = 3.freeze # Multiply calculated stop losses.
        @stop_loss_buffer = 0.freeze # Pad calculated stop losses with pips.

        # Take profit modes.
        # :none, :manual, :atr, :stop_loss_percent
        @take_profit_mode   = :stop_loss_percent
        @take_profit_factor = 1.freeze # Multiply calculated take profits.
        @take_profit_buffer = 0.freeze # Pad calculated take profits with pips.

        # Break even modes.
        # :none, :manual, :atr, :take_profit_percent
        @break_even_mode   = :manual
        @break_even_buffer = 5.freeze # Additional pips to secure when moving stop to break even.

        # Protective stop loss modes.
        # :none, :candle_trailing_stop, :trailing_stop_manual, :trailing_stop_atr, :trailing_stop_take_profit_percent, :jumping_stop_manual, :jumping_stop_atr, :jumping_stop_take_profit_percent
        @protective_stop_loss_mode = :trailing_stop_atr

        stop_loss_values = {
          none:             nil,
          manual:           [30],
          atr:              [20],
          previous_candles: [15]
        }

        take_profit_values = {
          none:              nil,
          manual:            [35],
          atr:               [20],
          stop_loss_percent: [150]
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
          sun: [['00:00', '00:00']],
          mon: [['00:00', '00:00']],
          tue: [['00:00', '00:00']],
          wed: [['00:00', '00:00']],
          thu: [['00:00', '00:00']],
          fri: [['00:00', '00:00']],
          sat: [['00:00', '00:00']]
        }.freeze

        true
      end
    end
  end
end
