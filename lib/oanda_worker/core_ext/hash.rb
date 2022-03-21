class Hash
  def transform_keys
    result = {}
    each_key do |key|
      result[yield(key)] = self[key]
    end
    result
  end

  def transform_keys!
    keys.each do |key|
      self[yield(key)] = delete(key)
    end
    self
  end

  def stringify_keys
    transform_keys(&:to_s)
  end

  def stringify_keys!
    transform_keys!(&:to_s)
  end

  def symbolize_keys
    transform_keys { |key| key.to_sym rescue key }
  end

  def symbolize_keys!
    transform_keys! { |key| key.to_sym rescue key }
  end
end
