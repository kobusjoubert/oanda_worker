class Overlay
  def initialize(options = {})
    options.symbolize_keys!
    require_attributes = self.class::REQUIRED_ATTRIBUTES.dup

    if require_attributes.include?(:candles_or_values)
      require_attributes.delete(:candles_or_values)
      raise ArgumentError, "The [:candles or :values] attributes are missing" unless options.keys.include?(:candles) || options.keys.include?(:values)
    end

    missing_attributes = require_attributes - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end
  end
end
