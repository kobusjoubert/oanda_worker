module Strategies
  class Strategy45826 < Strategy
    INSTRUMENT       = INSTRUMENTS['US30_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['US30_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 1.freeze

    attr_reader :risk_factor, :box_size, :granularity

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @risk_factor = 500.freeze
      @box_size    = 10.freeze
      @granularity = 'D'.freeze
    end

    include Strategies::Steps::Strategy45XXX
  end
end
