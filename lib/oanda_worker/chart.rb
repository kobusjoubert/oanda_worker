class Chart
  def initialize(options = {})
    options.symbolize_keys!
    missing_attributes = self.class::REQUIRED_ATTRIBUTES.dup - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end
  end
end
