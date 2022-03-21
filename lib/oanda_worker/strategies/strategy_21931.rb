module Strategies
  class Strategy21931 < Strategy
    INSTRUMENT       = INSTRUMENTS['WTICO_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['WTICO_USD']['pip_size'].freeze
    BUFFER_DISTANCE  = 0.15.freeze
    EMA_COUNT        = 5.freeze
    WMA_COUNT        = 150.freeze
    WMA_POINTS       = 40.freeze
    CANDLES_REQUIRED = (WMA_COUNT + WMA_POINTS - 1).freeze

    attr_reader :stop_loss, :round_decimal, :weighted_moving_average, :exponential_moving_average, :buffer_high, :buffer_low

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

      buffer_sum = weighted_moving_average.points[-1]

      (weighted_moving_average.points.count - 2).downto(0).each do |i|
        buffer_sum = (buffer_sum + weighted_moving_average.points[i]) / 2
      end

      @buffer_high = buffer_sum + BUFFER_DISTANCE
      @buffer_low  = buffer_sum - BUFFER_DISTANCE
      @stop_loss   = 55.0 * PIP_SIZE

      if enter_long?
        if create_long_order!
          options = {
            id:        oanda_order['orderFillTransaction']['id'],
            stop_loss: (oanda_order['orderFillTransaction']['price'].to_f - stop_loss).round(round_decimal)
          }
          update_trade!(options)
          return true
        end
      end

      if enter_short?
        if create_short_order!
          options = {
            id:        oanda_order['orderFillTransaction']['id'],
            stop_loss: (oanda_order['orderFillTransaction']['price'].to_f + stop_loss).round(round_decimal)
          }
          update_trade!(options)
          return true
        end
      end

      false
    end

    def step_2
      return true unless self.oanda_trade = oanda_last_trade

      @weighted_moving_average    = Overlays::WeightedMovingAverage.new(candles: candles, count: WMA_COUNT, points_count: WMA_POINTS)
      @exponential_moving_average = Overlays::ExponentialMovingAverage.new(candles: candles, count: EMA_COUNT)

      buffer_sum = weighted_moving_average.points[-1]

      (weighted_moving_average.points.count - 2).downto(0).each do |i|
        buffer_sum = (buffer_sum + weighted_moving_average.points[i]) / 2
      end

      @buffer_high = buffer_sum + BUFFER_DISTANCE
      @buffer_low  = buffer_sum - BUFFER_DISTANCE

      if self.send("exit_#{oanda_trade_type}?")
        return exit_trade!
      end

      false
    end

    private

    def enter_long?
      weighted_moving_average.points[-1] > buffer_high &&
      weighted_moving_average.points[-2] <= buffer_high
    end

    def enter_short?
      weighted_moving_average.points[-1] < buffer_low &&
      weighted_moving_average.points[-2] >= buffer_low
    end

    def exit_long?
      exponential_moving_average.points[-1] < buffer_high &&
      exponential_moving_average.points[-2] >= buffer_high
    end

    def exit_short?
      exponential_moving_average.points[-1] > buffer_low &&
      exponential_moving_average.points[-2] <= buffer_low
    end
  end
end
