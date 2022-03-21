class Prediction
  ML_ENDPOINT = 'https://realtime.machinelearning.us-east-1.amazonaws.com'.freeze

  def initialize(options = {})
    options.symbolize_keys!
    require_attributes = self.class::REQUIRED_ATTRIBUTES.dup

    missing_attributes = require_attributes - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end
  end

  private

  # Round to the nearest 0.5
  def time_difference(time_a, time_b)
    time_diff = time_b.to_f - time_a.to_f
    time_diff = time_diff / 60 / 60
    (time_diff * 2).round / 2.0
  end

  def average(candle)
    ((candle['mid']['h'].to_f + candle['mid']['l'].to_f) / 2).round(4)
  end
end
