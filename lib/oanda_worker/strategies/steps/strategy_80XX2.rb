# Strategy80XX2
#
#   Advanced Patterns (Gartleys, Bats & Cyphers).
#
# To enter a trade:
#
#   Wait for a pattern to give buy or sell order signal.
#   Place the valid pattern orders.
#   Remove the orders when the pattern is invalidated.
#
# To exit a trade:
#
#   Wait for stop loss to trigger.
#   Wait for target 1 to trigger.
#
# Notes
#
#   Only place orders if risk to reward ration is at least a 1:1.
#
module Strategies
  module Steps
    module Strategy80XX2
      include Strategies::Steps::Strategy8XXX2

      private

      def create_long_order?
        @create_long_order ||= (bullish_cyphers && bullish_cyphers.points.any?) || (bullish_gartleys && bullish_gartleys.points.any?) || (bullish_bats && bullish_bats.points.any?)
      end

      def create_short_order?
        @create_short_order ||= (bearish_cyphers && bearish_cyphers.points.any?) || (bearish_gartleys && bearish_gartleys.points.any?) || (bearish_bats && bearish_bats.points.any?)
      end

      def bullish_pattern_to_use
        pattern = (bullish_cyphers && bullish_cyphers.points.last) || (bullish_gartleys && bullish_gartleys.points.last) || (bullish_bats && bullish_bats.points.last)
        return nil unless pattern

        bullish_cyphers && bullish_cyphers.points.map do |pattern_points|
          pattern = pattern_points if pattern_points[:d] > pattern[:d]
        end

        bullish_gartleys && bullish_gartleys.points.map do |pattern_points|
          pattern = pattern_points if pattern_points[:d] > pattern[:d]
        end

        bullish_bats && bullish_bats.points.map do |pattern_points|
          pattern = pattern_points if pattern_points[:d] > pattern[:d]
        end

        pattern
      end

      def bearish_pattern_to_use
        pattern = (bearish_cyphers && bearish_cyphers.points.last) || (bearish_gartleys && bearish_gartleys.points.last) || (bearish_bats && bearish_bats.points.last)
        return nil unless pattern

        bearish_cyphers && bearish_cyphers.points.map do |pattern_points|
          pattern = pattern_points if pattern_points[:d] < pattern[:d]
        end

        bearish_gartleys && bearish_gartleys.points.map do |pattern_points|
          pattern = pattern_points if pattern_points[:d] < pattern[:d]
        end

        bearish_bats && bearish_bats.points.map do |pattern_points|
          pattern = pattern_points if pattern_points[:d] < pattern[:d]
        end

        pattern
      end
    end
  end
end
