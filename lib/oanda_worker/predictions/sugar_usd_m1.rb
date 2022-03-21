# TODO: Refactor.
module Predictions
  class SUGARUSDM1 < Prediction
    REQUIRED_ATTRIBUTES = [:aws_client, :candles].freeze
    ML_MODEL            = 'ml-abcdefghijk'.freeze # TODO: Replace with your model ID.
    CANDLES_REQUIRED    = 240

    attr_accessor :aws_client, :candles, :values
    attr_reader   :count

    def initialize(options = {})
      super
      raise OandaWorker::PredictionError, "#{self.class} ERROR. No candles to work with. candles: #{candles}" if candles['candles'].empty?
      raise OandaWorker::PredictionError, "#{self.class} ERROR. Not enough candles returned, #{count} needed. candles: #{candles['candles'].count}" if candles['candles'].count < CANDLES_REQUIRED
      @candles = candles.dup
      @values  = candles['candles'].map{ |candle| average(candle) } if candles
    end

    def prediction
      moving_average_m = Overlays::SimpleMovingAverage.new(values: values[0..59], count: 60).point
      moving_average_l = Overlays::SimpleMovingAverage.new(values: values[0..119], count: 60).point
      moving_average_k = Overlays::SimpleMovingAverage.new(values: values[0..179], count: 60).point

      moving_average_f = Overlays::SimpleMovingAverage.new(values: values[180..189], count: 10).point
      moving_average_e = Overlays::SimpleMovingAverage.new(values: values[190..199], count: 10).point
      moving_average_d = Overlays::SimpleMovingAverage.new(values: values[200..209], count: 10).point
      moving_average_c = Overlays::SimpleMovingAverage.new(values: values[210..219], count: 10).point
      moving_average_b = Overlays::SimpleMovingAverage.new(values: values[220..229], count: 10).point
      moving_average_a = Overlays::SimpleMovingAverage.new(values: values[230..239], count: 10).point

      begin
        hour        = Time.parse(candles['candles'][-1]['time']).utc.hour
        hour_m_diff = time_difference(Time.parse(candles['candles'][-1]['time']).utc, Time.parse(candles['candles'][0]['time']).utc)
        hour_f_diff = time_difference(Time.parse(candles['candles'][-1]['time']).utc, Time.parse(candles['candles'][180]['time']).utc)
      rescue ArgumentError, TypeError
        hour        = Time.at(candles['candles'][-1]['time'].to_f).utc.hour
        hour_m_diff = time_difference(Time.at(candles['candles'][-1]['time'].to_f).utc, Time.at(candles['candles'][0]['time'].to_f).utc)
        hour_f_diff = time_difference(Time.at(candles['candles'][-1]['time'].to_f).utc, Time.at(candles['candles'][180]['time'].to_f).utc)
      end

      response = aws_client.predict({
        ml_model_id: ML_MODEL,
        predict_endpoint: ML_ENDPOINT,
        record: {
          'a' => moving_average_a.round(4).to_s,
          'b' => moving_average_b.round(4).to_s,
          'c' => moving_average_c.round(4).to_s,
          'd' => moving_average_d.round(4).to_s,
          'e' => moving_average_e.round(4).to_s,
          'f' => moving_average_f.round(4).to_s,
          'k' => moving_average_k.round(4).to_s,
          'l' => moving_average_l.round(4).to_s,
          'm' => moving_average_m.round(4).to_s,
          'hour' => hour.to_s,
          'hour_f_diff' => hour_f_diff.to_s,
          'hour_m_diff' => hour_m_diff.to_s
        }
      })

      response.prediction.predicted_value
    end
  end
end
