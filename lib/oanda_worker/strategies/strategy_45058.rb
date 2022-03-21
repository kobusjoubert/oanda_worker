module Strategies
  class Strategy45058 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
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
      @granularity = 'H1'.freeze
    end

    include Strategies::Steps::Strategy45XXX
  end
end
