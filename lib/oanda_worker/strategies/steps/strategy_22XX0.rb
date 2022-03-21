# Strategy22XX0
#
# To exit a trade:
#
#   Uses a stop loss order and take profit order on the trade to exit the trade.
#
module Strategies
  module Steps
    module Strategy22XX0
      def step_1
        return false if oanda_active_trades.any? && step_to(2) && queue_next_run

        candles(smooth: true, include_incomplete_candles: false)

        if enter_long?
          @take_profit = take_profit_pips * PIP_SIZE
          @stop_loss   = take_profit_pips * stop_loss_factor * PIP_SIZE

          if create_long_order!
            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f + take_profit).round(round_decimal),
              stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f - stop_loss).round(round_decimal)
            }
            update_trade!(options)
            return true if queue_next_run
          end
        end

        if enter_short?
          @take_profit = take_profit_pips * PIP_SIZE
          @stop_loss   = take_profit_pips * stop_loss_factor * PIP_SIZE

          if create_short_order!
            options = {
              id:          oanda_order['orderFillTransaction']['id'],
              take_profit: (oanda_order['orderFillTransaction']['price'].to_f - take_profit).round(round_decimal),
              stop_loss:   (oanda_order['orderFillTransaction']['price'].to_f + stop_loss).round(round_decimal)
            }
            update_trade!(options)
            return true if queue_next_run
          end
        end

        false
      end

      def step_2
        return false if oanda_active_trades.empty? && reset_steps && queue_next_run
        false
      end

      private

      def enter_long?
        conditions = 0

        if exhaustion_moving_average_1.top_shadow_sizes[-1] < (exhaustion_moving_average_1.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_1.bottom_shadow_sizes[-1] > (exhaustion_moving_average_1.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.top_shadow_sizes[-1] < (exhaustion_moving_average_2.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_2.bottom_shadow_sizes[-1] > (exhaustion_moving_average_2.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.top_shadow_sizes[-1] < (exhaustion_moving_average_3.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_3.bottom_shadow_sizes[-1] > (exhaustion_moving_average_3.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        return false if conditions == 0

        if exhaustion_moving_average_1.top_shadow_sizes[-2] < (exhaustion_moving_average_1.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_1.bottom_shadow_sizes[-2] > (exhaustion_moving_average_1.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.top_shadow_sizes[-2] < (exhaustion_moving_average_2.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_2.bottom_shadow_sizes[-2] > (exhaustion_moving_average_2.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.top_shadow_sizes[-2] < (exhaustion_moving_average_3.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_3.bottom_shadow_sizes[-2] > (exhaustion_moving_average_3.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        false
      end

      def enter_short?
        conditions = 0

        if exhaustion_moving_average_1.bottom_shadow_sizes[-1] < (exhaustion_moving_average_1.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_1.top_shadow_sizes[-1] > (exhaustion_moving_average_1.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.bottom_shadow_sizes[-1] < (exhaustion_moving_average_2.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_2.top_shadow_sizes[-1] > (exhaustion_moving_average_2.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.bottom_shadow_sizes[-1] < (exhaustion_moving_average_3.average_body_sizes[-1] * leading_shadow_factor) && exhaustion_moving_average_3.top_shadow_sizes[-1] > (exhaustion_moving_average_3.average_body_sizes[-1] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        return false if conditions == 0

        if exhaustion_moving_average_1.bottom_shadow_sizes[-2] < (exhaustion_moving_average_1.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_1.top_shadow_sizes[-2] > (exhaustion_moving_average_1.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[0]
        end

        if exhaustion_moving_average_2.bottom_shadow_sizes[-2] < (exhaustion_moving_average_2.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_2.top_shadow_sizes[-2] > (exhaustion_moving_average_2.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[1]
        end

        if exhaustion_moving_average_3.bottom_shadow_sizes[-2] < (exhaustion_moving_average_3.average_body_sizes[-2] * leading_shadow_factor) && exhaustion_moving_average_3.top_shadow_sizes[-2] > (exhaustion_moving_average_3.average_body_sizes[-2] * lagging_shadow_factor)
          conditions        += 1
          @take_profit_pips += take_profit_pip_increments[2]
        end

        return true if conditions >= 2
        false
      end

      def options
        @options ||= {
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
    end
  end
end
