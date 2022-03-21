class Time
  def api(time = Time.now)
    # Time.now.utc.iso8601
    # Time.now.utc.to_datetime.rfc3339(9)
    # DateTime.parse(Time.now.utc.to_s).rfc3339(9)
    time.utc.to_datetime.rfc3339(9).gsub(/\+00:00$/, 'Z')
  end
end
