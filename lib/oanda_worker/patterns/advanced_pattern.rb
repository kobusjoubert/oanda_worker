# Structures
#
# points
#
#   [{ pattern: :bat, x: 1.1000, a: 1.1700, b: 1.1300, c: 1.1500, d: 1.1100, x_date: '', a_date: '', b_date: '', c_date: '' }]
#
# sequences
#
#   [{
#     pattern: :bat, look_for: :x,
#     x: 1.1000, a: 1.1700, b: 1.1300, c: 1.1500, d: 1.1100,
#     x_date: '', a_date: '', b_date: '', c_date: '',
#     extreme_after_x: 1.7000, extreme_after_a: 1.2000, extreme_after_b: 1.5000, extreme_after_c: 1.2000,
#     extreme_after_x_date: '', extreme_after_a_date: '', extreme_after_b_date: '', extreme_after_c_date: '',
#     extreme_after_a_close: 1.2000, extreme_after_b_close: 1.6000,
#     reverse_extreme_after_x: 1.1000,
#     invalid_a_list: [], invalid_b_list: []
#   }]
#
# invalid_a_list
#
#   [{ a_date: '' }]
#
# invalid_b_list
#
#   [{ b_date: '' }]
#
# Notes
#
#   We must always have one structure in the sequences array looking for x (sequence[:look_for]: :x).
#   When a valid x point (pivot point) has been found, we log the prices and dates.
#   When the x gets violated, we delete the entire structure from the sequences array.
#
module Patterns
  class AdvancedPattern < Pattern
    REQUIRED_ATTRIBUTES = [:candles, :pip_size, :round_decimal].freeze

    attr_accessor :candles, :count, :pip_size, :round_decimal, :granularity, :pattern, :trend, :min_pattern_pips, :max_pattern_pips,
                  :pivot_left_bars, :pivot_right_bars, :rsi_count, :b_retracement, :c_retracement, :d_retracement, :c_extension, :d_extension,
                  :limit_patterns_by_pip_size, :limit_patterns_by_candle_count, :limit_patterns_by_steep_legs,
                  :min_candle_count_x_to_a, :min_candle_count_a_to_b, :min_candle_count_b_to_c, :max_candle_count_c_to_d,
                  :min_steep_legs_x_to_a, :min_steep_legs_a_to_b, :min_steep_legs_b_to_c, :min_steep_legs_c_to_d,
                  :max_sma_swings_x_to_a, :max_sma_swings_a_to_b, :max_sma_swings_b_to_c, :max_sma_swings_c_to_d,
                  :sma_leading_counts, :sma_lagging_counts, :rsi_overbought, :rsi_oversold
    attr_reader   :sequences, :sequence_structure, :pivot_bars_needed, :rsi_bars_needed, :valid_time_sequence_check, :sma_bars_needed, :sma_direction_change_mapping

    def initialize(options = {})
      super
      @limit_patterns_by_pip_size     ||= true.freeze
      @limit_patterns_by_candle_count ||= true.freeze
      @limit_patterns_by_steep_legs   ||= true.freeze

      # Minimum candles required per leg.
      @min_candle_count_x_to_a ||= 1.freeze
      @min_candle_count_a_to_b ||= 1.freeze
      @min_candle_count_b_to_c ||= 1.freeze
      @max_candle_count_c_to_d ||= 200.freeze

      # Amount of times a leg has to at least push through the previous highs or lows of previous candles of the leg.
      # This makes for a more aesthetically pleasing pattern.
      @min_steep_legs_x_to_a ||= 1.freeze
      @min_steep_legs_a_to_b ||= 2.freeze
      @min_steep_legs_b_to_c ||= 2.freeze
      @min_steep_legs_c_to_d ||= 1.freeze

      # When the x to a leg starts on a bullish pattern, the leading sma should cross over the lagging sma max_sma_swings_x_to_a times before being invalidated.
      # When the a to b leg starts on a bullish pattern, the leading sma should cross under the lagging sma max_sma_swings_a_to_b times before being invalidated.
      # When the b to c leg starts on a bullish pattern, the leading sma should cross over the lagging sma max_sma_swings_b_to_c times before being invalidated.
      # When the c to d leg starts on a bullish pattern, the leading sma should cross under the lagging sma max_sma_swings_c_to_d times before being invalidated.
      # As soon as a new leg starts, we use the current sma to initialize the first sma directions and counts.
      @max_sma_swings_x_to_a ||= 3.freeze
      @max_sma_swings_a_to_b ||= 3.freeze
      @max_sma_swings_b_to_c ||= 3.freeze
      @max_sma_swings_c_to_d ||= 5.freeze

      @sma_bars_needed   = [@sma_leading_counts.max, @sma_lagging_counts.max].max.freeze
      @pivot_bars_needed = (@pivot_left_bars + 1 + @pivot_right_bars).freeze
      @rsi_bars_needed   = [(@rsi_count * 2 + @pivot_right_bars), 30].max.freeze
      @pattern           = self.class.to_s.split('::')[1].downcase.to_sym.freeze

      @sma_direction_change_mapping = { up: :down, down: :up }

      @sequence_structure = {
        pattern: @pattern, candle_time: nil, look_for: :x,
        x: nil, a: nil, b: nil, c: nil, d: nil,
        x_opposite: nil, a_opposite: nil, b_opposite: nil, c_opposite: nil,
        x_date: nil, a_date: nil, b_date: nil, c_date: nil,
        extreme_after_x: nil, extreme_after_a: nil, extreme_after_b: nil, extreme_after_c: nil,
        extreme_after_x_opposite: nil, extreme_after_a_opposite: nil, extreme_after_b_opposite: nil, extreme_after_c_opposite: nil,
        extreme_after_x_date: nil, extreme_after_a_date: nil, extreme_after_b_date: nil, extreme_after_c_date: nil,
        extreme_after_a_close: nil, extreme_after_b_close: nil,
        reverse_extreme_after_x: nil,
        invalid_a_list: [], invalid_b_list: [],
        candle_count_x_to_a: 0, candle_count_a_to_b: 0, candle_count_b_to_c: 0, candle_count_c_to_d: 0,
        steep_legs_x_to_a: 0, steep_legs_a_to_b: 0, steep_legs_b_to_c: 0, steep_legs_c_to_d: 0,
        xa_leg_sma_direction: nil, ab_leg_sma_direction: nil, bc_leg_sma_direction: nil, cd_leg_sma_direction: nil,
        xa_leg_sma_swings: 0, ab_leg_sma_swings: 0, bc_leg_sma_swings: 0, cd_leg_sma_swings: 0,
        xa_leg_sma_started: false, ab_leg_sma_started: false, bc_leg_sma_started: false, cd_leg_sma_started: false,
        xa_leg_sma_broken: false, ab_leg_sma_broken: false, bc_leg_sma_broken: false, cd_leg_sma_broken: false
      }.to_s.freeze

      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count} needed. candles: #{candles['candles'].count}; count: #{count}" if candles['candles'].count < count
      @candles                   = candles.dup
      @valid_time_sequence_check = false # This should only be used for debugging! It takes a long time to do time parsing.
    end

    # [{ x: 1.1000, a: 1.1700, b: 1.1300, c: 1.1500, d: 1.1100, x_date: '', a_date: '', b_date: '', c_date: '' }]
    def points
      @points ||= begin
        points    = []
        sequences = [eval(sequence_structure)]

        # Loop over last 300 candles.
        candles['candles'].each_with_index do |candle, i|
          next if i < (pivot_bars_needed - 1) # 3 candles needed to calculate pivot points.
          next if i < (rsi_bars_needed - 1)   # 30 candles needed to calculate the x point rsi.
          next if i < (sma_bars_needed - 1)   # 7 candles needed to calculate leading and lagging moving averages.

          # Pivot candles are only used to determine the x point.
          pivot_candles = candles['candles'][(i - pivot_bars_needed + 1)..i].dup
          pivot_candle  = pivot_candles[(pivot_candles.size.to_f / 2.to_f).floor]

          # RSI candles are only used to determine the x point for now.
          rsi_candles = { 'instrument' => candles['instrument'], 'granularity' => candles['granularity'], 'candles' => candles['candles'][(i - rsi_bars_needed + 1)..i].dup }.freeze

          # SMA candles are used on all legs.
          sma_values = candles['candles'][(i - sma_bars_needed + 1)..i].map{ |candle| candle['mid']['c'] }

          sma_leading_points = []
          sma_lagging_points = []

          sma_leading_counts.each_with_index do |sma_leading_count, i|
            sma_leading_points << Overlays::SimpleMovingAverage.new(values: sma_values, count: sma_leading_count, plotted_ahead: pivot_right_bars).point if [0].include?(i)
            sma_leading_points << Overlays::SimpleMovingAverage.new(values: sma_values, count: sma_leading_count).point if [1, 2, 3, 4].include?(i)
          end

          sma_lagging_counts.each_with_index do |sma_lagging_count, i|
            sma_lagging_points << Overlays::SimpleMovingAverage.new(values: sma_values, count: sma_lagging_count, plotted_ahead: pivot_right_bars).point if [0].include?(i)
            sma_lagging_points << Overlays::SimpleMovingAverage.new(values: sma_values, count: sma_lagging_count).point if [1, 2, 3, 4].include?(i)
          end

          rsi = Indicators::RelativeStrengthIndex.new(candles: rsi_candles, count: rsi_count)

          # We cannot alter the array while we loop over it! We have to alter the array after the iteration has completed.
          sequences_to_remove   = []
          look_for_new_sequence = false

          sequences.each_with_index do |sequence, j|

            # 0)
            #
            # General updates.

            candle_time_changed = false

            if candle_time_changed?(sequence, candle)
              update_last_candle_time!(sequence, candle)
              candle_time_changed = true
            end

            # 1)
            #
            # Initialize extreme points when sequence[:look_for] changed in previous candle.

            if [:a].include?(sequence[:look_for])
              initialize_extreme_after_x!(sequence, candle, pivot_candle) unless sequence[:extreme_after_x]
            end

            if [:b].include?(sequence[:look_for])
              initialize_extreme_after_a!(sequence, candle) unless sequence[:extreme_after_a]
            end

            if [:c].include?(sequence[:look_for])
              initialize_extreme_after_b!(sequence, candle) unless sequence[:extreme_after_b]
            end

            if [:d].include?(sequence[:look_for])
              initialize_extreme_after_c!(sequence, candle) unless sequence[:extreme_after_c]
            end

            # 2)
            #
            # Update candle counts.

            if limit_patterns_by_candle_count
              if [:a].include?(sequence[:look_for])
                sequence[:candle_count_x_to_a] += 1 if candle_time_changed
              end

              if [:b].include?(sequence[:look_for])
                sequence[:candle_count_a_to_b] += 1 if candle_time_changed
              end

              # FIXME: Does not get incremented once more when valid d point was found.
              if [:c].include?(sequence[:look_for])
                sequence[:candle_count_b_to_c] += 1 if candle_time_changed
              end

              if [:d].include?(sequence[:look_for])
                sequence[:candle_count_c_to_d] += 1 if candle_time_changed
              end
            end

            if limit_patterns_by_steep_legs
              if [:a].include?(sequence[:look_for])
                if sequence[:steep_legs_x_to_a] == 0
                  sequence[:steep_legs_x_to_a] = 1 if x_opposite_violated?(sequence)
                end

                if sequence[:steep_legs_x_to_a] >= 1
                  sequence[:steep_legs_x_to_a] += 1 if extreme_after_x_violated?(sequence, candle)
                end
              end

              if [:b].include?(sequence[:look_for])
                if sequence[:steep_legs_a_to_b] == 0
                  sequence[:steep_legs_a_to_b] = 1 if a_opposite_violated?(sequence)
                end

                if sequence[:steep_legs_a_to_b] >= 1
                  sequence[:steep_legs_a_to_b] += 1 if extreme_after_a_violated?(sequence, candle)
                end
              end

              if [:c].include?(sequence[:look_for])
                if sequence[:steep_legs_b_to_c] == 0
                  sequence[:steep_legs_b_to_c] = 1 if b_opposite_violated?(sequence)
                end

                if sequence[:steep_legs_b_to_c] >= 1
                  sequence[:steep_legs_b_to_c] += 1 if extreme_after_b_violated?(sequence, candle)
                end
              end

              if [:d].include?(sequence[:look_for])
                if sequence[:steep_legs_c_to_d] == 0
                  sequence[:steep_legs_c_to_d] = 1 if c_opposite_violated?(sequence)
                end

                if sequence[:steep_legs_c_to_d] >= 1
                  sequence[:steep_legs_c_to_d] += 1 if extreme_after_c_violated?(sequence, candle)
                end
              end
            end

            # 3)
            #
            # Extremes after XABC updates from candles.
            # Update extremes from candles when violated.
            # The extremes won't be updated if the extreme hasn't been initialized before.

            update_reverse_extreme_after_x!(sequence, candle) if reverse_extreme_after_x_violated?(sequence, candle)

            if [:a].include?(sequence[:look_for])
              update_extreme_after_x!(sequence, candle) if extreme_after_x_violated?(sequence, candle)
            end

            if [:b].include?(sequence[:look_for])
              update_extreme_after_x!(sequence, candle) if extreme_after_x_violated?(sequence, candle)
              update_extreme_after_a!(sequence, candle) if extreme_after_a_violated?(sequence, candle)
            end

            if [:c].include?(sequence[:look_for])
              update_extreme_after_a!(sequence, candle) if extreme_after_a_violated?(sequence, candle)
              update_extreme_after_b!(sequence, candle) if extreme_after_b_violated?(sequence, candle)
            end

            if [:d].include?(sequence[:look_for])
              update_extreme_after_b!(sequence, candle) if extreme_after_b_violated?(sequence, candle)
              update_extreme_after_c!(sequence, candle) if extreme_after_c_violated?(sequence, candle)
            end

            # 4)
            #
            # XABC updates from extreme points.
            # Update points from extremes when violated.
            # Merge counts when look_for changes.

            if [:a].include?(sequence[:look_for])
              initialize_a!(sequence) unless sequence[:a]

              if a_violated?(sequence)
                update_a!(sequence)
                clear_everything_after_a!(sequence)
              end
            end

            if [:b].include?(sequence[:look_for])
              initialize_b!(sequence) unless sequence[:b]

              if a_violated?(sequence)
                update_a!(sequence)
                merge_counts_a_to_b_with_x_to_a!(sequence)
                clear_everything_after_a!(sequence)
                sequence[:look_for] = :a
              end

              if b_violated?(sequence)
                update_b!(sequence)
                clear_everything_after_b!(sequence)
              end
            end

            if [:c].include?(sequence[:look_for])
              initialize_c!(sequence) unless sequence[:c]

              if b_violated?(sequence)
                if extreme_after_b_violates_extreme_after_x?(sequence)
                  update_extreme_after_x_to_extreme_after_b!(sequence, candle)
                  # remember_invalid_a!(sequence) # Don't think this is necessary.
                  update_a!(sequence)
                  merge_counts_b_to_c_with_x_to_a!(sequence)
                  merge_counts_a_to_b_with_x_to_a!(sequence)
                  clear_everything_after_a!(sequence)
                  sequence[:look_for] = :a
                else
                  update_b!(sequence)
                  merge_counts_b_to_c_with_a_to_b!(sequence)
                  clear_everything_after_b!(sequence)
                  sequence[:look_for] = :b
                end
              end

              if c_violated?(sequence)
                update_c!(sequence)
                clear_everything_after_c!(sequence)
              end
            end

            if [:d].include?(sequence[:look_for])
              initialize_d!(sequence) unless sequence[:d]

              if c_violated?(sequence)
                if extreme_after_c_violates_extreme_after_a?(sequence)
                  update_extreme_after_a_to_extreme_after_c!(sequence, candle)
                  update_b!(sequence)
                  merge_counts_c_to_d_with_a_to_b!(sequence)
                  merge_counts_b_to_c_with_a_to_b!(sequence)
                  clear_everything_after_b!(sequence)
                  sequence[:look_for] = :b
                else
                  update_c!(sequence)
                  merge_counts_c_to_d_with_b_to_c!(sequence)
                  clear_everything_after_c!(sequence)
                  sequence[:look_for] = :c
                end
              end

              if d_violated?(sequence)
                # update_d!(sequence)
              end
            end

            # 5)
            #
            # Broken legs.
            # Remove sequences when legs are broken or malformed.

            if [:a, :b, :c, :d].include?(sequence[:look_for])
              if !sequence[:xa_leg_sma_broken] && xa_leg_broken?(sequence, sma_leading_points[1], sma_lagging_points[1])
                sequence[:xa_leg_sma_broken] = true
              end
            end

            if [:b, :c, :d].include?(sequence[:look_for])
              if !sequence[:ab_leg_sma_broken] && ab_leg_broken?(sequence, sma_leading_points[2], sma_lagging_points[2])
                sequence[:ab_leg_sma_broken] = true
              end
            end

            if [:c, :d].include?(sequence[:look_for])
              if !sequence[:bc_leg_sma_broken] && bc_leg_broken?(sequence, sma_leading_points[3], sma_lagging_points[3])
                sequence[:bc_leg_sma_broken] = true
              end
            end

            if [:d].include?(sequence[:look_for])
              # Must set sequence[:cd_leg_sma_started] to true before the cd_leg_broken? can return true.
              if !sequence[:cd_leg_sma_broken] && cd_leg_broken?(sequence, sma_leading_points[4], sma_lagging_points[4])
                sequence[:cd_leg_sma_broken] = true
              end
            end

            if [:a].include?(sequence[:look_for])
              if sequence[:xa_leg_sma_broken]
                sequences_to_remove.push(j).uniq!
                next
              end
            end

            if [:b].include?(sequence[:look_for])
              if sequence[:ab_leg_sma_broken]
                sequences_to_remove.push(j).uniq!
                next
              end
            end

            if [:c].include?(sequence[:look_for])
              if sequence[:bc_leg_sma_broken]
                sequences_to_remove.push(j).uniq!
                next
              end
            end

            if [:d].include?(sequence[:look_for])
              if sequence[:cd_leg_sma_broken]
                sequences_to_remove.push(j).uniq!
                next
              end
            end

            # 6)
            #
            # XABCD pattern validation checks from XABCD points.
            # Do not change sequence[:look_for] after this section.
            # When sequence[:look_for] has been changed here, first thing on next candle we initialize the extreme points.

            if sequence[:look_for] == :d && valid_d?(sequence, candle)
              initialize_d!(sequence)
            end

            if sequence[:look_for] == :c && valid_c?(sequence, candle) && valid_d?(sequence, candle)
              sequence[:look_for] = :d
            end

            if sequence[:look_for] == :b && valid_b?(sequence, candle)
              sequence[:look_for] = :c
            end

            if sequence[:look_for] == :a && valid_a?(sequence, candle)
              sequence[:look_for] = :b
            end

            if sequence[:look_for] == :x && valid_x?(pivot_candles, rsi, sma_leading_points[0], sma_lagging_points[0])
              initialize_counts!(sequence)
              initialize_reverse_extreme_after_x!(sequence, pivot_candle)
              initialize_x!(sequence, pivot_candles, pivot_candle)
              sequence[:look_for] = :a

              # We must always have at least one sequence looking for x (sequence[:look_for]: :x)
              look_for_new_sequence = true
            end

            # 7)
            #
            # Leg sma starting points.
            # Keep on updating leg starting points off of the simple moving averages.
            # This needs to happen after checking for valid_a?, valid_b?, valib_c? & valid_d?...

            if [:a, :b, :c, :d].include?(sequence[:look_for])
              if sequence[:xa_leg_sma_started] && xa_leg_sma_direction_changed?(sequence, sma_leading_points[1], sma_lagging_points[1])
                update_xa_leg_sma_direction!(sequence)
              end

              if !sequence[:xa_leg_sma_started] && xa_leg_sma_starting?(sequence, sma_leading_points[1], sma_lagging_points[1])
                sequence[:xa_leg_sma_started] = true
                initialize_xa_leg_sma_direction!(sequence)
              end
            end

            if [:b, :c, :d].include?(sequence[:look_for])
              if sequence[:ab_leg_sma_started] && ab_leg_sma_direction_changed?(sequence, sma_leading_points[2], sma_lagging_points[2])
                update_ab_leg_sma_direction!(sequence)
              end

              if !sequence[:ab_leg_sma_started] && ab_leg_sma_starting?(sequence, sma_leading_points[2], sma_lagging_points[2])
                sequence[:ab_leg_sma_started] = true
                initialize_ab_leg_sma_direction!(sequence)
              end
            end

            if [:c, :d].include?(sequence[:look_for])
              if sequence[:bc_leg_sma_started] && bc_leg_sma_direction_changed?(sequence, sma_leading_points[3], sma_lagging_points[3])
                update_bc_leg_sma_direction!(sequence)
              end

              if !sequence[:bc_leg_sma_started] && bc_leg_sma_starting?(sequence, sma_leading_points[3], sma_lagging_points[3])
                sequence[:bc_leg_sma_started] = true
                initialize_bc_leg_sma_direction!(sequence)
              end
            end

            if [:d].include?(sequence[:look_for])
              if sequence[:cd_leg_sma_started] && cd_leg_sma_direction_changed?(sequence, sma_leading_points[4], sma_lagging_points[4])
                update_cd_leg_sma_direction!(sequence)
              end

              if !sequence[:cd_leg_sma_started] && cd_leg_sma_starting?(sequence, sma_leading_points[4], sma_lagging_points[4])
                sequence[:cd_leg_sma_started] = true
                initialize_cd_leg_sma_direction!(sequence)
              end
            end

            # 8)
            #
            # Violations.
            # Violations from extreme points.

            if [:a, :b, :c].include?(sequence[:look_for])
              if x_violated_before?(sequence)
                sequences_to_remove.push(j).uniq!
                next
              end
            end

            if [:b, :c].include?(sequence[:look_for])
              if x_violated?(sequence)
                sequences_to_remove.push(j).uniq!
                next
              end
            end

            if [:d].include?(sequence[:look_for])
              if d_violated?(sequence)
                sequences_to_remove.push(j).uniq!
                next
              end
            end

            if [:b, :c].include?(sequence[:look_for])
              if b_fib_extreme_violated?(sequence)
                merge_counts_b_to_c_with_x_to_a!(sequence) if sequence[:look_for] == :c
                merge_counts_a_to_b_with_x_to_a!(sequence)
                update_extreme_after_x_to_extreme_after_b!(sequence, candle) if sequence[:extreme_after_b] && extreme_after_b_violates_extreme_after_x?(sequence)
                remember_invalid_a!(sequence)
                clear_a!(sequence)
                clear_everything_after_a!(sequence)
                sequence[:look_for] = :a
                next
              end
            end

            if [:c, :d].include?(sequence[:look_for])
              if c_fib_extreme_violated?(sequence)
                if sequence[:extreme_after_c] && extreme_after_c_violates_extreme_after_a?(sequence)
                  merge_counts_c_to_d_with_a_to_b!(sequence) if sequence[:look_for] == :d
                  merge_counts_b_to_c_with_a_to_b!(sequence)
                  update_extreme_after_a_to_extreme_after_c!(sequence, candle)
                  remember_invalid_b!(sequence)
                  clear_b!(sequence)
                  clear_everything_after_b!(sequence)
                  sequence[:look_for] = :b
                  next
                end

                merge_counts_c_to_d_with_x_to_a!(sequence) if sequence[:look_for] == :d
                merge_counts_b_to_c_with_x_to_a!(sequence)
                merge_counts_a_to_b_with_x_to_a!(sequence)
                update_extreme_after_x_to_extreme_after_b!(sequence, candle) if sequence[:extreme_after_b] && extreme_after_b_violates_extreme_after_x?(sequence)
                remember_invalid_a!(sequence)
                clear_a!(sequence)
                clear_everything_after_a!(sequence)
                sequence[:look_for] = :a
                next
              end
            end

            # 9)
            #
            # Remove or update inferior patterns.

            if [:d].include?(sequence[:look_for]) && limit_patterns_by_candle_count && too_many_candles_after_c?(sequence)
              merge_counts_c_to_d_with_x_to_a!(sequence)
              merge_counts_b_to_c_with_x_to_a!(sequence)
              merge_counts_a_to_b_with_x_to_a!(sequence)
              update_extreme_after_x_to_extreme_after_b!(sequence, candle) if sequence[:extreme_after_b] && extreme_after_b_violates_extreme_after_x?(sequence)
              remember_invalid_a!(sequence)
              clear_a!(sequence)
              clear_everything_after_a!(sequence)
              sequence[:look_for] = :a
              next
            end
          end

          sequences_to_remove.sort.reverse.each do |sequence_index|
            sequences.delete_at(sequence_index)
          end

          sequences.push(eval(sequence_structure)) if look_for_new_sequence
        end

        sequences.each do |sequence|
          points << sequence.select{ |key| [:pattern, :x, :a, :b, :c, :d, :x_date, :a_date, :b_date, :c_date].include?(key) } if valid_sequence?(sequence, candles['candles'].last)
        end

        @sequences = sequences

        points
      end
    end

    private

    def retracement(point_1, point_2, point_3 = nil, percentage = nil)
      return (point_3.to_f - point_2.to_f).abs / (point_1.to_f - point_2.to_f).abs if point_3
      return point_2.to_f + ((point_1.to_f - point_2.to_f) * percentage) if percentage
    end

    def extension(point_1, point_2, point_3 = nil, percentage = nil)
      return ((point_1.to_f - point_3.to_f).abs / (point_1.to_f - point_2.to_f).abs).abs if point_3
      return point_1.to_f + ((point_2.to_f - point_1.to_f) * percentage) if percentage
    end

    def pivot_high(pivot_candles, left_bars, right_bars)
      highest_high_left   = pivot_candles.first['mid']['h'].to_f
      highest_high_right  = pivot_candles.last['mid']['h'].to_f
      pivot_test_candle = pivot_candles[left_bars]['mid']['h'].to_f

      pivot_candles.each_with_index do |candle, i|
        if i < left_bars && candle['mid']['h'].to_f > highest_high_left
          highest_high_left = candle['mid']['h'].to_f
        end

        if i > left_bars && candle['mid']['h'].to_f > highest_high_right
          highest_high_right = candle['mid']['h'].to_f
        end
      end

      pivot_test_candle > highest_high_left && pivot_test_candle > highest_high_right ? pivot_test_candle : nil
    end

    def pivot_low(pivot_candles, left_bars, right_bars)
      lowest_low_left   = pivot_candles.first['mid']['l'].to_f
      lowest_low_right  = pivot_candles.last['mid']['l'].to_f
      pivot_test_candle = pivot_candles[left_bars]['mid']['l'].to_f

      pivot_candles.each_with_index do |candle, i|
        if i < left_bars && candle['mid']['l'].to_f < lowest_low_left
          lowest_low_left = candle['mid']['l'].to_f
        end

        if i > left_bars && candle['mid']['l'].to_f < lowest_low_right
          lowest_low_right = candle['mid']['l'].to_f
        end
      end

      pivot_test_candle < lowest_low_left && pivot_test_candle < lowest_low_right ? pivot_test_candle : nil
    end

    def pivot_high?(pivot_candles, left_bars, right_bars)
      pivot_high(pivot_candles, left_bars, right_bars) ? true : false
    end

    def pivot_low?(pivot_candles, left_bars, right_bars)
      pivot_low(pivot_candles, left_bars, right_bars) ? true : false
    end

    def time_after_time?(sequence, point_1, point_2)
      Time.parse(sequence[point_1]) > Time.parse(sequence[point_2])
    end

    def time_before_time?(sequence, point_1, point_2)
      Time.parse(sequence[point_1]) < Time.parse(sequence[point_2])
    end

    def valid_time_sequence?(sequence)
      if sequence[:extreme_after_b_date] && sequence[:extreme_after_c_date] && time_after_time?(sequence, :extreme_after_b_date, :extreme_after_c_date)
        return false
      end

      if sequence[:extreme_after_a_date] && sequence[:extreme_after_b_date] && time_after_time?(sequence, :extreme_after_a_date, :extreme_after_b_date)
        return false
      end

      if sequence[:extreme_after_x_date] && sequence[:extreme_after_a_date] && time_after_time?(sequence, :extreme_after_x_date, :extreme_after_a_date)
        return false
      end

      if sequence[:b_date] && sequence[:c_date] && time_after_time?(sequence, :b_date, :c_date)
        return false
      end

      if sequence[:a_date] && sequence[:b_date] && time_after_time?(sequence, :a_date, :b_date)
        return false
      end

      if sequence[:x_date] && sequence[:a_date] && time_after_time?(sequence, :x_date, :a_date)
        return false
      end

      true
    end

    def invalid_time_sequence?(sequence)
      !valid_time_sequence?(sequence)
    end

    def in_invalid_a_list?(sequence)
      sequence[:invalid_a_list].map do |invalid_a|
        return true if invalid_a[:a_date] == sequence[:extreme_after_x_date]
      end

      false
    end

    def in_invalid_b_list?(sequence)
      sequence[:invalid_b_list].map do |invalid_a|
        return true if invalid_a[:b_date] == sequence[:extreme_after_a_date]
      end

      false
    end

    def too_many_candles_after_c?(sequence)
      return false unless limit_patterns_by_candle_count
      sequence[:candle_count_c_to_d] > max_candle_count_c_to_d
    end

    def pattern_pips_met?(sequence)
      return true unless limit_patterns_by_pip_size

      pattern_size =
        case pattern
        when :gartley, :bat
          (sequence[:x] - sequence[:a]).abs / pip_size
        when :cypher
          (sequence[:x] - sequence[:c]).abs / pip_size
        end

      pattern_size >= min_pattern_pips && pattern_size <= max_pattern_pips
    end

    def valid_sequence?(sequence, candle)
      sequence[:d] &&
      sequence[:x_date] != sequence[:a_date] &&
      sequence[:a_date] != sequence[:b_date] &&
      sequence[:b_date] != sequence[:c_date] &&
      pattern_pips_met?(sequence)
    end

    def valid_x?(pivot_candles, rsi, sma_leading_point, sma_lagging_point)
      case trend
      when :bullish
        return false if sma_leading_point > sma_lagging_point
        return false if rsi.points[-1 -pivot_right_bars] > rsi_oversold
        return !!pivot_low(pivot_candles, pivot_left_bars, pivot_right_bars)
      when :bearish
        return false if sma_leading_point < sma_lagging_point
        return false if rsi.points[-1 -pivot_right_bars] < rsi_overbought
        return !!pivot_high(pivot_candles, pivot_left_bars, pivot_right_bars)
      end
    end

    # Must update sequence[:extreme_after_x] before calling this method.
    def valid_a?(sequence, candle)
      # return false if sequence[:a_date] != sequence[:candle_time] # This should not be called here, we're always looking for b!
      return false if sequence[:a_date] == sequence[:x_date]
      return false if in_invalid_a_list?(sequence)
      return false if limit_patterns_by_candle_count && sequence[:candle_count_x_to_a] < min_candle_count_x_to_a
      return false if limit_patterns_by_steep_legs && sequence[:steep_legs_x_to_a] < min_steep_legs_x_to_a
      # return false if limit_patterns_by_steep_legs && !x_opposite_violated?(sequence)

      case trend
      when :bullish
        return sequence[:extreme_after_x] > sequence[:x]
      when :bearish
        return sequence[:extreme_after_x] < sequence[:x]
      end
    end

    # Must update sequence[:extreme_after_x] & sequence[:extreme_after_a] before calling this method.
    def valid_b?(sequence, candle)
      return false if sequence[:b_date] != sequence[:candle_time]
      return false if sequence[:b_date] == sequence[:a_date]
      return false if in_invalid_b_list?(sequence)
      return false if limit_patterns_by_candle_count && sequence[:candle_count_a_to_b] < min_candle_count_a_to_b
      return false if limit_patterns_by_steep_legs && sequence[:steep_legs_a_to_b] < min_steep_legs_a_to_b
      # return false if limit_patterns_by_steep_legs && !a_opposite_violated?(sequence)

      if [:gartley, :bat].include?(pattern)
        b_retracement.each do |range|
          return true if retracement(sequence[:x], sequence[:extreme_after_x], sequence[:extreme_after_a]) >= range[0] && retracement(sequence[:x], sequence[:extreme_after_x], sequence[:extreme_after_a]) < range[1]
        end
      end

      if [:cypher].include?(pattern)
        b_retracement.each do |range|
          return true if retracement(sequence[:x], sequence[:extreme_after_x], sequence[:extreme_after_a]) >= range[0] && retracement(sequence[:x], sequence[:extreme_after_x], sequence[:extreme_after_a_close]) < range[1]
        end
      end

      false
    end

    # Must update sequence[:extreme_after_b] before calling this method.
    def valid_c?(sequence, candle)
      return false if sequence[:c_date] != sequence[:candle_time]
      return false if sequence[:c_date] == sequence[:b_date]
      return false if limit_patterns_by_candle_count && sequence[:candle_count_b_to_c] < min_candle_count_b_to_c
      return false if limit_patterns_by_steep_legs && sequence[:steep_legs_b_to_c] < min_steep_legs_b_to_c
      # return false if limit_patterns_by_steep_legs && !b_opposite_violated?(sequence)

      if [:gartley, :bat].include?(pattern)
        case trend
        when :bullish
          return retracement(sequence[:a], sequence[:b], sequence[:extreme_after_b]) >= c_retracement[0] && sequence[:extreme_after_b] < sequence[:a]
        when :bearish
          return retracement(sequence[:a], sequence[:b], sequence[:extreme_after_b]) >= c_retracement[0] && sequence[:extreme_after_b] > sequence[:a]
        end
      end

      if [:cypher].include?(pattern)
        case trend
        when :bullish
          return extension(sequence[:x], sequence[:a], sequence[:extreme_after_b]) >= c_extension[0] && extension(sequence[:x], sequence[:a], sequence[:extreme_after_b_close]) <= c_extension[1] && sequence[:extreme_after_b] > sequence[:a]
        when :bearish
          return extension(sequence[:x], sequence[:a], sequence[:extreme_after_b]) >= c_extension[0] && extension(sequence[:x], sequence[:a], sequence[:extreme_after_b_close]) <= c_extension[1] && sequence[:extreme_after_b] < sequence[:a]
        end
      end

      false
    end

    # If we are still looking for a valid_c, the c point would've been initialized on the first run after look_for bacame c.
    # The extreme_after_c will be initialized as soon as a valid_c and a valid_d was found. Now we need to keep track of the price movement after c.
    def valid_d?(sequence, candle)
      if [:gartley].include?(pattern)
        d_point = extension(sequence[:a], sequence[:b], nil, d_extension[0]).round(round_decimal)

        case trend
        when :bullish
          return d_point < sequence[:b] && (sequence[:extreme_after_c] || sequence[:c]) > d_point
        when :bearish
          return d_point > sequence[:b] && (sequence[:extreme_after_c] || sequence[:c]) < d_point
        end
      end

      if [:bat].include?(pattern)
        d_point = retracement(sequence[:x], sequence[:a], nil, d_retracement[0]).round(round_decimal)

        case trend
        when :bullish
          return d_point < sequence[:b] && (sequence[:extreme_after_c] || sequence[:c]) > d_point
        when :bearish
          return d_point > sequence[:b] && (sequence[:extreme_after_c] || sequence[:c]) < d_point
        end
      end

      if [:cypher].include?(pattern)
        d_point = retracement(sequence[:x], sequence[:c], nil, d_retracement[0]).round(round_decimal)

        case trend
        when :bullish
          return d_point < sequence[:b] && (sequence[:extreme_after_c] || sequence[:c]) > d_point
        when :bearish
          return d_point > sequence[:b] && (sequence[:extreme_after_c] || sequence[:c]) < d_point
        end
      end

      false
    end

    # Violations By Extreme Points.
    def extreme_violated?(point, sequence)
      point = point.to_sym
      return false if sequence[point].nil?

      # When the point has just been found, we still need to initialize the extreme point.
      # This can only happen on the next candle where we will initiailize the extreme.
      case point
      when :a, :x_opposite
        return false unless sequence[:extreme_after_x]
      when :x, :b, :a_opposite
        return false unless sequence[:extreme_after_a]
      when :c, :b_opposite
        return false unless sequence[:extreme_after_b]
      when :d, :c_opposite
        return false unless sequence[:extreme_after_c]
      end

      case trend
      when :bullish
        return sequence[:extreme_after_a] < sequence[:x] if point == :x
        return sequence[:extreme_after_x] > sequence[:a] if point == :a
        return sequence[:extreme_after_a] < sequence[:b] if point == :b
        return sequence[:extreme_after_b] > sequence[:c] if point == :c
        return sequence[:extreme_after_c] < sequence[:d] if point == :d
        return sequence[:extreme_after_x] > sequence[:x_opposite] if point == :x_opposite
        return sequence[:extreme_after_a] < sequence[:a_opposite] if point == :a_opposite
        return sequence[:extreme_after_b] > sequence[:b_opposite] if point == :b_opposite
        return sequence[:extreme_after_c] < sequence[:c_opposite] if point == :c_opposite
      when :bearish
        return sequence[:extreme_after_a] > sequence[:x] if point == :x
        return sequence[:extreme_after_x] < sequence[:a] if point == :a
        return sequence[:extreme_after_a] > sequence[:b] if point == :b
        return sequence[:extreme_after_b] < sequence[:c] if point == :c
        return sequence[:extreme_after_c] > sequence[:d] if point == :d
        return sequence[:extreme_after_x] < sequence[:x_opposite] if point == :x_opposite
        return sequence[:extreme_after_a] > sequence[:a_opposite] if point == :a_opposite
        return sequence[:extreme_after_b] < sequence[:b_opposite] if point == :b_opposite
        return sequence[:extreme_after_c] > sequence[:c_opposite] if point == :c_opposite
      end
    end

    def x_violated?(sequence)
      extreme_violated?(:x, sequence)
    end

    def a_violated?(sequence)
      extreme_violated?(:a, sequence)
    end

    def b_violated?(sequence)
      extreme_violated?(:b, sequence)
    end

    def c_violated?(sequence)
      extreme_violated?(:c, sequence)
    end

    def d_violated?(sequence)
      extreme_violated?(:d, sequence)
    end

    def x_opposite_violated?(sequence)
      extreme_violated?(:x_opposite, sequence)
    end

    def a_opposite_violated?(sequence)
      extreme_violated?(:a_opposite, sequence)
    end

    def b_opposite_violated?(sequence)
      extreme_violated?(:b_opposite, sequence)
    end

    def c_opposite_violated?(sequence)
      extreme_violated?(:c_opposite, sequence)
    end

    def x_violated_before?(sequence)
      return false unless sequence[:reverse_extreme_after_x]

      case trend
      when :bullish
        return sequence[:reverse_extreme_after_x] < sequence[:x]
      when :bearish
        return sequence[:reverse_extreme_after_x] > sequence[:x]
      end
    end

    # Violations By Candles.
    def candle_violated?(point, sequence, candle)
      point = point.to_sym
      return false if sequence[point].nil?

      case trend
      when :bullish
        return candle['mid']['h'].to_f > sequence[point] if [:extreme_after_x, :extreme_after_b].include?(point)
        return candle['mid']['l'].to_f < sequence[point] if [:extreme_after_a, :extreme_after_c, :reverse_extreme_after_x].include?(point)
      when :bearish
        return candle['mid']['l'].to_f < sequence[point] if [:extreme_after_x, :extreme_after_b].include?(point)
        return candle['mid']['h'].to_f > sequence[point] if [:extreme_after_a, :extreme_after_c, :reverse_extreme_after_x].include?(point)
      end
    end

    def extreme_after_x_violated?(sequence, candle)
      candle_violated?(:extreme_after_x, sequence, candle)
    end

    def extreme_after_a_violated?(sequence, candle)
      candle_violated?(:extreme_after_a, sequence, candle)
    end

    def extreme_after_b_violated?(sequence, candle)
      candle_violated?(:extreme_after_b, sequence, candle)
    end

    def extreme_after_c_violated?(sequence, candle)
      candle_violated?(:extreme_after_c, sequence, candle)
    end

    def extreme_after_b_violated_extreme_after_x?(sequence, candle)
      return false unless sequence[:extreme_after_b] && sequence[:extreme_after_x]

      case trend
      when :bullish
        sequence[:extreme_after_b] > sequence[:extreme_after_x]
      when :bearish
        sequence[:extreme_after_b] < sequence[:extreme_after_x]
      end
    end

    def reverse_extreme_after_x_violated?(sequence, candle)
      candle_violated?(:reverse_extreme_after_x, sequence, candle)
    end

    def b_fib_extreme_violated?(sequence)
      return false unless sequence[:x] && sequence[:a]

      if [:gartley, :bat].include?(pattern)
        return false unless sequence[:extreme_after_a]
        return retracement(sequence[:x], sequence[:a], sequence[:extreme_after_a]) >= b_retracement.map{ |range| range[1] }.max
      end

      if [:cypher].include?(pattern)
        return false unless sequence[:extreme_after_a_close]
        return retracement(sequence[:x], sequence[:a], sequence[:extreme_after_a_close]) > b_retracement.map{ |range| range[1] }.max
      end
    end

    def c_fib_extreme_violated?(sequence)
      return false unless sequence[:x] && sequence[:a]

      if [:gartley, :bat].include?(pattern)
        return false unless sequence[:extreme_after_b]

        case trend
        when :bullish
          return sequence[:extreme_after_b] > sequence[:a]
        when :bearish
          return sequence[:extreme_after_b] < sequence[:a]
        end
      end

      if [:cypher].include?(pattern)
        return false unless sequence[:extreme_after_b_close]
        return extension(sequence[:x], sequence[:a], sequence[:extreme_after_b_close]) > c_extension[1]
      end
    end

    def extreme_after_b_violates_extreme_after_x?(sequence)
      raise OandaWorker::IndicatorError, "Can not compare extreme_after_b with extreme_after_x! sequence: #{sequence}" unless sequence[:extreme_after_b] && sequence[:extreme_after_x]
      case trend
      when :bullish
        sequence[:extreme_after_b] > sequence[:extreme_after_x]
      when :bearish
        sequence[:extreme_after_b] < sequence[:extreme_after_x]
      end
    end

    def extreme_after_c_violates_extreme_after_a?(sequence)
      raise OandaWorker::IndicatorError, "Can not compare extreme_after_c with extreme_after_a! sequence: #{sequence}" unless sequence[:extreme_after_c] && sequence[:extreme_after_a]
      case trend
      when :bullish
        sequence[:extreme_after_c] < sequence[:extreme_after_a]
      when :bearish
        sequence[:extreme_after_c] > sequence[:extreme_after_a]
      end
    end

    def leg_sma_starting?(leg, sequence, sma_leading_point, sma_lagging_point)
      case trend
      when :bullish
        return true if [:xa, :bc].include?(leg) && sma_leading_point > sma_lagging_point
        return true if [:ab, :cd].include?(leg) && sma_leading_point < sma_lagging_point
      when :bearish
        return true if [:xa, :bc].include?(leg) && sma_leading_point < sma_lagging_point
        return true if [:ab, :cd].include?(leg) && sma_leading_point > sma_lagging_point
      end

      false
    end

    def xa_leg_sma_starting?(sequence, sma_leading_point, sma_lagging_point)
      leg_sma_starting?(:xa, sequence, sma_leading_point, sma_lagging_point)
    end

    def ab_leg_sma_starting?(sequence, sma_leading_point, sma_lagging_point)
      return false unless sequence[:xa_leg_sma_started]
      leg_sma_starting?(:ab, sequence, sma_leading_point, sma_lagging_point)
    end

    def bc_leg_sma_starting?(sequence, sma_leading_point, sma_lagging_point)
      return false unless sequence[:ab_leg_sma_started]
      leg_sma_starting?(:bc, sequence, sma_leading_point, sma_lagging_point)
    end

    def cd_leg_sma_starting?(sequence, sma_leading_point, sma_lagging_point)
      return false unless sequence[:bc_leg_sma_started]
      leg_sma_starting?(:cd, sequence, sma_leading_point, sma_lagging_point)
    end

    def leg_sma_direction_changed?(leg, sequence, sma_leading_point, sma_lagging_point)
      case sequence[:"#{leg}_leg_sma_direction"]
      when :down
        return true if [:xa, :bc].include?(leg) && sma_leading_point > sma_lagging_point
        return true if [:ab, :cd].include?(leg) && sma_leading_point < sma_lagging_point
      when :up
        return true if [:xa, :bc].include?(leg) && sma_leading_point < sma_lagging_point
        return true if [:ab, :cd].include?(leg) && sma_leading_point > sma_lagging_point
      end

      false
    end

    def xa_leg_sma_direction_changed?(sequence, sma_leading_point, sma_lagging_point)
      return false unless sequence[:xa_leg_sma_direction]
      leg_sma_direction_changed?(:xa, sequence, sma_leading_point, sma_lagging_point)
    end

    def ab_leg_sma_direction_changed?(sequence, sma_leading_point, sma_lagging_point)
      return false unless sequence[:ab_leg_sma_direction]
      leg_sma_direction_changed?(:ab, sequence, sma_leading_point, sma_lagging_point)
    end

    def bc_leg_sma_direction_changed?(sequence, sma_leading_point, sma_lagging_point)
      return false unless sequence[:bc_leg_sma_direction]
      leg_sma_direction_changed?(:bc, sequence, sma_leading_point, sma_lagging_point)
    end

    def cd_leg_sma_direction_changed?(sequence, sma_leading_point, sma_lagging_point)
      return false unless sequence[:cd_leg_sma_direction]
      leg_sma_direction_changed?(:cd, sequence, sma_leading_point, sma_lagging_point)
    end

    def leg_broken?(leg, sequence, sma_leading_point, sma_lagging_point)
      case leg
      when :xa
        return false unless sequence[:xa_leg_sma_started] && sequence[:xa_leg_sma_swings] >= max_sma_swings_x_to_a
      when :ab
        return false unless sequence[:ab_leg_sma_started] && sequence[:ab_leg_sma_swings] >= max_sma_swings_a_to_b
      when :bc
        return false unless sequence[:bc_leg_sma_started] && sequence[:bc_leg_sma_swings] >= max_sma_swings_b_to_c
      when :cd
        return false unless sequence[:cd_leg_sma_started] && sequence[:cd_leg_sma_swings] >= max_sma_swings_c_to_d
      end

      case trend
      when :bullish
        return true if [:xa, :bc].include?(leg) && sma_leading_point < sma_lagging_point
        return true if [:ab, :cd].include?(leg) && sma_leading_point > sma_lagging_point
      when :bearish
        return true if [:xa, :bc].include?(leg) && sma_leading_point > sma_lagging_point
        return true if [:ab, :cd].include?(leg) && sma_leading_point < sma_lagging_point
      end

      false
    end

    def xa_leg_broken?(sequence, sma_leading_point, sma_lagging_point)
      leg_broken?(:xa, sequence, sma_leading_point, sma_lagging_point)
    end

    def ab_leg_broken?(sequence, sma_leading_point, sma_lagging_point)
      leg_broken?(:ab, sequence, sma_leading_point, sma_lagging_point)
    end

    def bc_leg_broken?(sequence, sma_leading_point, sma_lagging_point)
      leg_broken?(:bc, sequence, sma_leading_point, sma_lagging_point)
    end

    def cd_leg_broken?(sequence, sma_leading_point, sma_lagging_point)
      leg_broken?(:cd, sequence, sma_leading_point, sma_lagging_point)
    end

    def candle_time_changed?(sequence, candle)
      sequence[:candle_time] != candle['time']
    end

    def update_last_candle_time!(sequence, candle)
      sequence[:candle_time] = candle['time']
    end

    def initialize_counts!(sequence)
      sequence[:candle_count_x_to_a] = 1 if limit_patterns_by_candle_count
      sequence[:steep_legs_x_to_a]   = 1 if limit_patterns_by_steep_legs
    end

    def update_x!(sequence, pivot_candles, pivot_candle)
      pivot_point_x =
        case trend
        when :bullish
          pivot_low(pivot_candles, pivot_left_bars, pivot_right_bars)
        when :bearish
          pivot_high(pivot_candles, pivot_left_bars, pivot_right_bars)
        end

      pivot_point_x_opposite =
        case trend
        when :bullish
          pivot_candle['mid']['h'].to_f
        when :bearish
          pivot_candle['mid']['l'].to_f
        end

      sequence[:x]          = pivot_point_x
      sequence[:x_opposite] = pivot_point_x_opposite
      sequence[:x_date]     = pivot_candle['time']
    end
    alias :initialize_x! :update_x!

    # sequence[:extreme_after_x] must be updated before calling this method.
    def update_a!(sequence)
      raise OandaWorker::IndicatorError, "Cannot update A. A would be before X? sequence: #{sequence}" if valid_time_sequence_check && time_before_time?(sequence, :extreme_after_x_date, :x_date)
      sequence[:a]          = sequence[:extreme_after_x]
      sequence[:a_opposite] = sequence[:extreme_after_x_opposite]
      sequence[:a_date]     = sequence[:extreme_after_x_date]
    end
    alias :initialize_a! :update_a!

    # sequence[:extreme_after_a] must be updated before calling this method.
    def update_b!(sequence)
      raise OandaWorker::IndicatorError, "Cannot update B. B would be before A? sequence: #{sequence}" if valid_time_sequence_check && time_before_time?(sequence, :extreme_after_a_date, :a_date)
      sequence[:b]          = sequence[:extreme_after_a]
      sequence[:b_opposite] = sequence[:extreme_after_a_opposite]
      sequence[:b_date]     = sequence[:extreme_after_a_date]
    end
    alias :initialize_b! :update_b!

    # sequence[:extreme_after_b] must be updated before calling this method.
    def update_c!(sequence)
      raise OandaWorker::IndicatorError, "Cannot update C. C would be before B? sequence: #{sequence}" if valid_time_sequence_check && time_before_time?(sequence, :extreme_after_b_date, :b_date)
      sequence[:c]          = sequence[:extreme_after_b]
      sequence[:c_opposite] = sequence[:extreme_after_b_opposite]
      sequence[:c_date]     = sequence[:extreme_after_b_date]
    end
    alias :initialize_c! :update_c!

    def update_d!(sequence)
      return if sequence[:d]

      case pattern
      when :gartley
        sequence[:d] = extension(sequence[:a], sequence[:b], nil, d_extension[0]).round(round_decimal)
      when :bat
        sequence[:d] = retracement(sequence[:x], sequence[:a], nil, d_retracement[0]).round(round_decimal)
      when :cypher
        sequence[:d] = retracement(sequence[:x], sequence[:c], nil, d_retracement[0]).round(round_decimal)
      end
    end
    alias :initialize_d! :update_d!

    def clear_a!(sequence)
      sequence[:a]          = nil
      sequence[:a_opposite] = nil
      sequence[:a_date]     = nil
    end

    def clear_b!(sequence)
      sequence[:b]          = nil
      sequence[:b_opposite] = nil
      sequence[:b_date]     = nil
    end

    def clear_c!(sequence)
      sequence[:c]          = nil
      sequence[:c_opposite] = nil
      sequence[:c_date]     = nil
    end

    def clear_d!(sequence)
      sequence[:d]      = nil
      sequence[:d_date] = nil
    end

    # When first setting the extreme_after_x after an x pivot has been found, we check if the extreme_after_x is a pivot.
    # On every check after this, it will be because the extreme_after_x has been violated, then naturally the extreme_after_x will be a pivot.
    def update_extreme_after_x!(sequence, candle, pivot_candle = nil)
      case trend
      when :bullish
        sequence[:extreme_after_x]          = candle['mid']['h'].to_f
        sequence[:extreme_after_x_opposite] = candle['mid']['l'].to_f
        sequence[:extreme_after_x_date]     = candle['time']
      when :bearish
        sequence[:extreme_after_x]          = candle['mid']['l'].to_f
        sequence[:extreme_after_x_opposite] = candle['mid']['h'].to_f
        sequence[:extreme_after_x_date]     = candle['time']
      end
    end
    alias :initialize_extreme_after_x! :update_extreme_after_x!

    def update_extreme_after_a!(sequence, candle)
      case trend
      when :bullish
        sequence[:extreme_after_a]          = candle['mid']['l'].to_f
        sequence[:extreme_after_a_opposite] = candle['mid']['h'].to_f
        sequence[:extreme_after_a_date]     = candle['time']
      when :bearish
        sequence[:extreme_after_a]          = candle['mid']['h'].to_f
        sequence[:extreme_after_a_opposite] = candle['mid']['l'].to_f
        sequence[:extreme_after_a_date]     = candle['time']
      end

      sequence[:extreme_after_a_close] = candle['mid']['c'].to_f
    end
    alias :initialize_extreme_after_a! :update_extreme_after_a!

    def update_extreme_after_b!(sequence, candle)
      case trend
      when :bullish
        sequence[:extreme_after_b]          = candle['mid']['h'].to_f
        sequence[:extreme_after_b_opposite] = candle['mid']['l'].to_f
        sequence[:extreme_after_b_date]     = candle['time']
      when :bearish
        sequence[:extreme_after_b]          = candle['mid']['l'].to_f
        sequence[:extreme_after_b_opposite] = candle['mid']['h'].to_f
        sequence[:extreme_after_b_date]     = candle['time']
      end

      sequence[:extreme_after_b_close] = candle['mid']['c'].to_f
    end
    alias :initialize_extreme_after_b! :update_extreme_after_b!

    def update_extreme_after_c!(sequence, candle)
      case trend
      when :bullish
        sequence[:extreme_after_c]          = candle['mid']['l'].to_f
        sequence[:extreme_after_c_opposite] = candle['mid']['h'].to_f
        sequence[:extreme_after_c_date]     = candle['time']
      when :bearish
        sequence[:extreme_after_c]          = candle['mid']['h'].to_f
        sequence[:extreme_after_c_opposite] = candle['mid']['l'].to_f
        sequence[:extreme_after_c_date]     = candle['time']
      end
    end
    alias :initialize_extreme_after_c! :update_extreme_after_c!

    def update_reverse_extreme_after_x!(sequence, candle)
      case trend
      when :bullish
        sequence[:reverse_extreme_after_x]      = candle['mid']['l'].to_f
        sequence[:reverse_extreme_after_x_date] = candle['time']
      when :bearish
        sequence[:reverse_extreme_after_x]      = candle['mid']['h'].to_f
        sequence[:reverse_extreme_after_x_date] = candle['time']
      end
    end
    alias :initialize_reverse_extreme_after_x! :update_reverse_extreme_after_x!

    def clear_extreme_after_x!(sequence)
      sequence[:extreme_after_x]          = nil
      sequence[:extreme_after_x_opposite] = nil
      sequence[:extreme_after_x_date]     = nil
    end

    def clear_extreme_after_a!(sequence)
      sequence[:extreme_after_a]          = nil
      sequence[:extreme_after_a_opposite] = nil
      sequence[:extreme_after_a_date]     = nil
      sequence[:extreme_after_a_close]    = nil
    end

    def clear_extreme_after_b!(sequence)
      sequence[:extreme_after_b]          = nil
      sequence[:extreme_after_b_opposite] = nil
      sequence[:extreme_after_b_date]     = nil
      sequence[:extreme_after_b_close]    = nil
    end

    def clear_extreme_after_c!(sequence)
      sequence[:extreme_after_c]          = nil
      sequence[:extreme_after_c_opposite] = nil
      sequence[:extreme_after_c_date]     = nil
    end

    def update_leg_sma_direction!(leg, sequence)
      case trend
      when :bullish
        direction = :up if [:xa, :bc].include?(leg)
        direction = :down if [:ab, :cd].include?(leg)

        if sequence[:"#{leg}_leg_sma_direction"]
          sequence[:"#{leg}_leg_sma_direction"] = sma_direction_change_mapping[sequence[:"#{leg}_leg_sma_direction"]]
          sequence[:"#{leg}_leg_sma_swings"]    += 1 if sequence[:"#{leg}_leg_sma_direction"] == direction
        else
          sequence[:"#{leg}_leg_sma_direction"] = direction
          sequence[:"#{leg}_leg_sma_swings"]    += 1
        end
      when :bearish
        direction = :down if [:xa, :bc].include?(leg)
        direction = :up if [:ab, :cd].include?(leg)

        if sequence[:"#{leg}_leg_sma_direction"]
          sequence[:"#{leg}_leg_sma_direction"] = sma_direction_change_mapping[sequence[:"#{leg}_leg_sma_direction"]]
          sequence[:"#{leg}_leg_sma_swings"]    += 1 if sequence[:"#{leg}_leg_sma_direction"] == direction
        else
          sequence[:"#{leg}_leg_sma_direction"] = direction
          sequence[:"#{leg}_leg_sma_swings"]    += 1
        end
      end
    end

    def update_xa_leg_sma_direction!(sequence)
      update_leg_sma_direction!(:xa, sequence)
    end
    alias :initialize_xa_leg_sma_direction! :update_xa_leg_sma_direction!

    def update_ab_leg_sma_direction!(sequence)
      update_leg_sma_direction!(:ab, sequence)
    end
    alias :initialize_ab_leg_sma_direction! :update_ab_leg_sma_direction!

    def update_bc_leg_sma_direction!(sequence)
      update_leg_sma_direction!(:bc, sequence)
    end
    alias :initialize_bc_leg_sma_direction! :update_bc_leg_sma_direction!

    def update_cd_leg_sma_direction!(sequence)
      update_leg_sma_direction!(:cd, sequence)
    end
    alias :initialize_cd_leg_sma_direction! :update_cd_leg_sma_direction!

    def clear_xa_leg!(sequence)
      sequence[:xa_leg_sma_swings]    = 0
      sequence[:xa_leg_sma_direction] = nil
      sequence[:xa_leg_sma_started]   = false
      sequence[:xa_leg_sma_broken]    = false
    end

    def clear_ab_leg!(sequence)
      sequence[:ab_leg_sma_swings]    = 0
      sequence[:ab_leg_sma_direction] = nil
      sequence[:ab_leg_sma_started]   = false
      sequence[:ab_leg_sma_broken]    = false
    end

    def clear_bc_leg!(sequence)
      sequence[:bc_leg_sma_swings]    = 0
      sequence[:bc_leg_sma_direction] = nil
      sequence[:bc_leg_sma_started]   = false
      sequence[:bc_leg_sma_broken]    = false
    end

    def clear_cd_leg!(sequence)
      sequence[:cd_leg_sma_swings]    = 0
      sequence[:cd_leg_sma_direction] = nil
      sequence[:cd_leg_sma_started]   = false
      sequence[:cd_leg_sma_broken]    = false
    end

    def clear_candle_count_after_x!(sequence)
      sequence[:candle_count_x_to_a] = 0 if limit_patterns_by_candle_count
    end

    def clear_candle_count_after_a!(sequence)
      sequence[:candle_count_a_to_b] = 0 if limit_patterns_by_candle_count
    end

    def clear_candle_count_after_b!(sequence)
      sequence[:candle_count_b_to_c] = 0 if limit_patterns_by_candle_count
    end

    def clear_candle_count_after_c!(sequence)
      sequence[:candle_count_c_to_d] = 0 if limit_patterns_by_candle_count
    end

    def clear_steep_legs_after_x!(sequence)
      sequence[:steep_legs_x_to_a] = 0 if limit_patterns_by_steep_legs
    end

    def clear_steep_legs_after_a!(sequence)
      sequence[:steep_legs_a_to_b] = 0 if limit_patterns_by_steep_legs
    end

    def clear_steep_legs_after_b!(sequence)
      sequence[:steep_legs_b_to_c] = 0 if limit_patterns_by_steep_legs
    end

    def clear_steep_legs_after_c!(sequence)
      sequence[:steep_legs_c_to_d] = 0 if limit_patterns_by_steep_legs
    end

    def clear_everything_after_x!(sequence)
      clear_candle_count_after_x!(sequence)
      clear_steep_legs_after_x!(sequence)
      clear_extreme_after_x!(sequence)
      clear_a!(sequence)
      clear_xa_leg!(sequence)
      clear_everything_after_a!(sequence)
    end

    def clear_everything_after_a!(sequence)
      clear_candle_count_after_a!(sequence)
      clear_steep_legs_after_a!(sequence)
      clear_extreme_after_a!(sequence)
      clear_b!(sequence)
      clear_ab_leg!(sequence)
      clear_everything_after_b!(sequence)
    end

    def clear_everything_after_b!(sequence)
      clear_candle_count_after_b!(sequence)
      clear_steep_legs_after_b!(sequence)
      clear_extreme_after_b!(sequence)
      clear_c!(sequence)
      clear_bc_leg!(sequence)
      clear_everything_after_c!(sequence)
    end

    def clear_everything_after_c!(sequence)
      clear_candle_count_after_c!(sequence)
      clear_steep_legs_after_c!(sequence)
      clear_extreme_after_c!(sequence)
      clear_d!(sequence)
      clear_cd_leg!(sequence)
    end

    def update_extreme_after_x_to_extreme_after_b!(sequence, candle)
      raise OandaWorker::IndicatorError, "Can not update extreme_after_x to extreme_after_b, extreme_after_b is nil! sequence: #{sequence}" unless sequence[:extreme_after_b]
      sequence[:extreme_after_x]          = sequence[:extreme_after_b]
      sequence[:extreme_after_x_opposite] = sequence[:extreme_after_b_opposite]
      sequence[:extreme_after_x_date]     = sequence[:extreme_after_b_date]
      initialize_a!(sequence)
      initialize_extreme_after_a!(sequence, candle)
    end

    def update_extreme_after_a_to_extreme_after_c!(sequence, candle)
      raise OandaWorker::IndicatorError, "Can not update extreme_after_a to extreme_after_c, extreme_after_c is nil! sequence: #{sequence}" unless sequence[:extreme_after_c]
      sequence[:extreme_after_a]          = sequence[:extreme_after_c]
      sequence[:extreme_after_a_opposite] = sequence[:extreme_after_c_opposite]
      sequence[:extreme_after_a_date]     = sequence[:extreme_after_c_date]
      initialize_b!(sequence)
      initialize_extreme_after_b!(sequence, candle)
    end

    def merge_counts_a_to_b_with_x_to_a!(sequence)
      sequence[:candle_count_x_to_a] += sequence[:candle_count_a_to_b]
      sequence[:steep_legs_x_to_a]   += sequence[:steep_legs_a_to_b]
    end

    def merge_counts_b_to_c_with_x_to_a!(sequence)
      sequence[:candle_count_x_to_a] += sequence[:candle_count_b_to_c]
      sequence[:steep_legs_x_to_a]   += sequence[:steep_legs_b_to_c]
    end

    def merge_counts_c_to_d_with_x_to_a!(sequence)
      sequence[:candle_count_x_to_a] += sequence[:candle_count_c_to_d]
      sequence[:steep_legs_x_to_a]   += sequence[:steep_legs_c_to_d]
    end

    def merge_counts_b_to_c_with_a_to_b!(sequence)
      sequence[:candle_count_a_to_b] += sequence[:candle_count_b_to_c]
      sequence[:steep_legs_a_to_b]   += sequence[:steep_legs_b_to_c]
    end

    def merge_counts_c_to_d_with_a_to_b!(sequence)
      sequence[:candle_count_a_to_b] += sequence[:candle_count_c_to_d]
      sequence[:steep_legs_a_to_b]   += sequence[:steep_legs_c_to_d]
    end

    def merge_counts_c_to_d_with_b_to_c!(sequence)
      sequence[:candle_count_b_to_c] += sequence[:candle_count_c_to_d]
      sequence[:steep_legs_b_to_c]   += sequence[:steep_legs_c_to_d]
    end

    def remember_invalid_a!(sequence)
      sequence[:invalid_a_list].push(a_date: sequence[:a_date])
    end

    def remember_invalid_b!(sequence)
      sequence[:invalid_b_list].push(b_date: sequence[:b_date])
    end
  end
end
