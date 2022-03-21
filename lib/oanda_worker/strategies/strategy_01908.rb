module Strategies
  class Strategy01908 < Strategy
    INSTRUMENT       = INSTRUMENTS['NATGAS_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NATGAS_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 40.freeze

    attr_reader :ichimoku_cloud, :bollinger_band, :previous_bollinger_band

    def step_1
      return true if self.oanda_trade = oanda_last_trade

      @ichimoku_cloud          = Overlays::IchimokuCloud.new(candles: candles, tenkan_sen_count: 20, kijun_sen_count: 20, senkou_span_b_count: 20, plotted_ahead: 20)
      @bollinger_band          = Overlays::BollingerBands.new(candles: candles, count: 14, deviation: 1)
      @previous_bollinger_band = Overlays::BollingerBands.new(candles: candles, count: 14, deviation: 1, plotted_ahead: 1)
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

      @ichimoku_cloud = Overlays::IchimokuCloud.new(candles: candles, tenkan_sen_count: 20, kijun_sen_count: 20, senkou_span_b_count: 20, plotted_ahead: 20)

      if self.send("exit_#{oanda_trade_type}?")
        return exit_trade!
      end

      false
    end

    private

    def enter_long?
      (ichimoku_cloud.senkou_span_a < bollinger_band.middle_band && ichimoku_cloud.senkou_span_b < bollinger_band.middle_band) &&
      (ichimoku_cloud.senkou_span_a > bollinger_band.lower_band || ichimoku_cloud.senkou_span_b > bollinger_band.lower_band) &&
      (candles['candles'][-1]['mid']['c'].to_f > bollinger_band.upper_band) &&
      (candles['candles'][-2]['mid']['c'].to_f < previous_bollinger_band.upper_band)
    end

    def enter_short?
      (ichimoku_cloud.senkou_span_a > bollinger_band.middle_band && ichimoku_cloud.senkou_span_b > bollinger_band.middle_band) &&
      (ichimoku_cloud.senkou_span_a < bollinger_band.upper_band || ichimoku_cloud.senkou_span_b < bollinger_band.upper_band) &&
      (candles['candles'][-1]['mid']['c'].to_f < bollinger_band.lower_band) &&
      (candles['candles'][-2]['mid']['c'].to_f > previous_bollinger_band.lower_band)
    end

    def exit_long?
      candles['candles'][-1]['mid']['c'].to_f < ichimoku_cloud.senkou_span_a || candles['candles'][-1]['mid']['c'].to_f < ichimoku_cloud.senkou_span_b
    end

    def exit_short?
      candles['candles'][-1]['mid']['c'].to_f > ichimoku_cloud.senkou_span_a || candles['candles'][-1]['mid']['c'].to_f > ichimoku_cloud.senkou_span_b
    end
  end
end
