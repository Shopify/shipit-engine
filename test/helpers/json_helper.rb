module JSONHelper
  def assert_json(path = nil, *args)
    value = follow_path(path.to_s.split('.'))
    if block_given?
      yield value
    elsif args.size == 1
      if args.first.nil?
        assert_nil value
      else
        assert_equal args.first, value
      end
    else
      raise ArgumentError, "Missing either expected_value or a block"
    end
  end

  def assert_json_keys(path, keys = nil)
    keys, path = path, nil if keys.nil?

    value = follow_path(path.to_s.split('.'))
    case value
    when Hash
      assert_equal keys.sort, value.keys.sort
    else
      assert false, "Expected #{path} to be a Hash, was: #{value.inspect}"
    end
  end

  def assert_no_json(path)
    segments = path.to_s.split('.')
    last_segment = segments.pop
    leaf = follow_path(segments)
    case leaf
    when Hash
      refute leaf.key?(last_segment), "Expected #{leaf.inspect} not to include #{last_segment.inspect}"
    when Array
      refute leaf.size > last_segment.to_i, "Expected #{leaf.inspect} to not have element at index #{last_segment.to_i}"
    else
      assert false, "Expected #{leaf.inspect} to be a Hash or Array"
    end
  end

  private

  def follow_path(segments)
    segments.inject(parsed_json) do |object, key|
      case object
      when Hash
        assert_includes object, key
        object[key]
      when Array
        assert object.size > key.to_i, "#{object.inspect} have no property #{key}"
        object[key.to_i]
      else
        assert false, "Expected #{object.inspect} to be a Hash or Array"
      end
    end
  end

  def parsed_json
    @parsed_json ||= ActiveSupport::JSON.decode(response.body)
  end
end
