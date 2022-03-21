module Strategies
  class Strategy42908 < Strategy
    INSTRUMENT       = INSTRUMENTS['NATGAS_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['NATGAS_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 2.freeze

    attr_reader :box_size, :distance_apart, :units_multiplier

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @box_size         = 2.freeze
      @distance_apart   = 3.freeze
      @units_multiplier = [3, 2, 1].freeze
    end

    include Strategies::Steps::Strategy42XXX
  end
end
