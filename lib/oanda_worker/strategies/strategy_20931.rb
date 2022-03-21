module Strategies
  class Strategy20931 < Strategy
    INSTRUMENT       = INSTRUMENTS['WTICO_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['WTICO_USD']['pip_size'].freeze
    WMA_COUNT        = 40.freeze
    WMA_POINTS       = 20.freeze
    CANDLES_REQUIRED = ([(WMA_COUNT + WMA_POINTS - 1), Predictions::WTICOUSDM1::CANDLES_REQUIRED].max).freeze

    attr_reader :take_profit, :stop_loss, :pips_required, :round_decimal, :weighted_moving_average, :buffer_high, :buffer_low

    def step_1
      return true if self.oanda_trade = oanda_last_trade

      @weighted_moving_average = Overlays::WeightedMovingAverage.new(candles: candles, count: WMA_COUNT, points_count: WMA_POINTS)
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

      buffer_sum      = weighted_moving_average.points.inject{ |sum, i| sum + i }
      buffer_distance = 0.05
      @buffer_high    = buffer_sum / weighted_moving_average.points.count + buffer_distance
      @buffer_low     = buffer_sum / weighted_moving_average.points.count - buffer_distance

      @take_profit    = 15.0 * PIP_SIZE
      @stop_loss      = 15.0 * PIP_SIZE
      @pips_required  = 0

      if enter_long?
        publish_prediction_values

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
        publish_prediction_values

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

    private

    def enter_long?
      weighted_moving_average.points[-1] > buffer_high &&
      weighted_moving_average.points[-2] <= buffer_high &&
      prediction > candles['candles'][-1]['mid']['c'].to_f + pips_required
    end

    def enter_short?
      weighted_moving_average.points[-1] < buffer_low &&
      weighted_moving_average.points[-2] >= buffer_low &&
      prediction < candles['candles'][-1]['mid']['c'].to_f - pips_required
    end
  end
end
