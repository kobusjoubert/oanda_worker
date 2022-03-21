module Strategies
  class Strategy01914 < Strategy
    INSTRUMENT       = INSTRUMENTS['SUGAR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['SUGAR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 840.freeze

    attr_reader :ichimoku_cloud, :bollinger_band, :previous_bollinger_band

    def step_1
      return true if self.oanda_trade = oanda_last_trade

      @ichimoku_cloud          = Overlays::IchimokuCloud.new(candles: candles, tenkan_sen_count: 70, kijun_sen_count: 420, senkou_span_b_count: 210, plotted_ahead: 420)
      @bollinger_band          = Overlays::BollingerBands.new(candles: candles, count: 70, deviation: 3)
      @previous_bollinger_band = Overlays::BollingerBands.new(candles: candles, count: 70, deviation: 3, plotted_ahead: 1)
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

      @ichimoku_cloud = Overlays::IchimokuCloud.new(candles: candles, tenkan_sen_count: 70, kijun_sen_count: 420, senkou_span_b_count: 210, plotted_ahead: 420)

      if self.send("exit_#{oanda_trade_type}?")
        return exit_trade!
      end

      false
    end

    private

    def enter_long?
      (ichimoku_cloud.senkou_span_a > bollinger_band.middle_band && ichimoku_cloud.senkou_span_b > bollinger_band.middle_band) &&
      (ichimoku_cloud.senkou_span_a < bollinger_band.upper_band || ichimoku_cloud.senkou_span_b < bollinger_band.upper_band) &&
      (candles['candles'][-1]['mid']['c'].to_f < bollinger_band.lower_band) &&
      (candles['candles'][-2]['mid']['c'].to_f > previous_bollinger_band.lower_band)
    end

    def enter_short?
      (ichimoku_cloud.senkou_span_a < bollinger_band.middle_band && ichimoku_cloud.senkou_span_b < bollinger_band.middle_band) &&
      (ichimoku_cloud.senkou_span_a > bollinger_band.lower_band || ichimoku_cloud.senkou_span_b > bollinger_band.lower_band) &&
      (candles['candles'][-1]['mid']['c'].to_f > bollinger_band.upper_band) &&
      (candles['candles'][-2]['mid']['c'].to_f < previous_bollinger_band.upper_band)
    end

    def exit_long?
      candles['candles'][-1]['mid']['c'].to_f > ichimoku_cloud.senkou_span_a || candles['candles'][-1]['mid']['c'].to_f > ichimoku_cloud.senkou_span_b
    end

    def exit_short?
      candles['candles'][-1]['mid']['c'].to_f < ichimoku_cloud.senkou_span_a || candles['candles'][-1]['mid']['c'].to_f < ichimoku_cloud.senkou_span_b
    end
  end
end
