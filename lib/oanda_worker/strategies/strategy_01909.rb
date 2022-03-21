module Strategies
  class Strategy01909 < Strategy
    INSTRUMENT       = INSTRUMENTS['NATGAS_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NATGAS_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 98.freeze

    attr_reader :ichimoku_cloud, :parabolic_stop_and_reverse

    def step_1
      return true if self.oanda_trade = oanda_last_trade

      @ichimoku_cloud             = Overlays::IchimokuCloud.new(candles: candles, tenkan_sen_count: 49, kijun_sen_count: 49, senkou_span_b_count: 49, plotted_ahead: 49)
      @parabolic_stop_and_reverse = Overlays::ParabolicStopAndReverse.new(candles: candles, acceleration_factor: 0.02, max_acceleration_factor: 0.05)
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
        return create_long_order!
      end

      if enter_short?
        return create_short_order!
      end

      false
    end

    def step_2
      return true unless self.oanda_trade = oanda_last_trade

      @ichimoku_cloud = Overlays::IchimokuCloud.new(candles: candles, tenkan_sen_count: 49, kijun_sen_count: 49, senkou_span_b_count: 49, plotted_ahead: 49)

      if self.send("exit_#{oanda_trade_type}?")
        return exit_trade!
      end

      false
    end

    private

    def enter_long?
      candles['candles'][-1]['mid']['c'].to_f > ichimoku_cloud.senkou_span_b &&
      ichimoku_cloud.senkou_span_b > parabolic_stop_and_reverse.point
    end

    def enter_short?
      candles['candles'][-1]['mid']['c'].to_f < ichimoku_cloud.senkou_span_b &&
      ichimoku_cloud.senkou_span_b < parabolic_stop_and_reverse.point
    end

    def exit_long?
      candles['candles'][-1]['mid']['c'].to_f < ichimoku_cloud.senkou_span_b
    end

    def exit_short?
      candles['candles'][-1]['mid']['c'].to_f > ichimoku_cloud.senkou_span_b
    end
  end
end
