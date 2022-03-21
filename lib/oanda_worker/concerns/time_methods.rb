module Concerns
  module TimeMethods
    def time_now_utc
      backtesting? ? backtest_time : Time.now.utc
    end

    def minute
      @minute ||= begin
        now    = time_now_utc
        minute = now.hour * 60 + now.min
      end
    end

    # Returns :mon, :tue, :wed, :thu, :fri, :sat, :sun.
    def week_day
      @week_day ||= time_now_utc.strftime('%a').downcase.to_sym
    end

    # Time can be given in UTC +2 Pretoria! The default is UTC.
    # Time will be converted to UTC inside this function.
    #
    #   06:00 = 04:00 UTC
    #   01:00 = 23:00 UTC
    #
    # Usage
    #
    #   time_inside?('06:01', '09:00', 'utc+2')
    #   time_inside?('06:01', '09:00')
    #
    #   time_inside?('00:00', '00:00') will always return true.
    def time_inside?(from, to, timezone = 'utc')
      time_adjustment =
        case timezone
        when 'utc'
          0
        when 'utc+2'
          -120
        end

      f    = from.split(':')
      t    = to.split(':')
      from = f[0].to_i * 60 + f[1].to_i + time_adjustment
      to   = t[0].to_i * 60 + t[1].to_i + time_adjustment
      from = 1_440 + from if from < 0
      to   = 1_440 + to if to < 0

      if to <= from
        minute >= from || minute < to
      else
        minute >= from && minute < to
      end
    end

    def time_outside?(from, to, timezone = 'utc')
      !time_inside?(from, to, timezone)
    end

    # Requires an array:
    #
    #   @times = [['00:00', '01:00'], ['10:00', '12:00'], ['20:00', '23:00']]
    def times_inside?(times, timezone = 'utc')
      times.each do |range|
        return true if time_inside?(range[0], range[1], timezone)
      end

      false
    end

    def times_outside?(times, timezone = 'utc')
      !times_inside?(times, timezone = 'utc')
    end

    # Requires a hash:
    #
    #   @trading_times = {
    #     sun: [['00:00', '00:00']],
    #     mon: [['00:00', '00:00']],
    #     tue: [['00:00', '00:00']],
    #     wed: [['00:00', '00:00']],
    #     thu: [['00:00', '00:00']],
    #     fri: [['00:00', '00:00']],
    #     sat: [['00:00', '00:00']]
    #   }
    def day_and_time_inside?(times)
      days = times.keys
      return false unless days.include?(week_day)
      times_inside?(times[week_day])
    end

    def day_and_time_outside?(times)
      days = times.keys
      return true unless days.include?(week_day)
      times_outside?(times[week_day])
    end
  end
end
