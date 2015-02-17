module JSONHelper
  def assert_json(path = nil, *args)
    value = path.to_s.split('.').inject(parsed_json) do |object, key|
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
    if block_given?
      yield value
    elsif args.size == 1
      assert_equal args.first, value
    else
      raise ArgumentError, "Missing either expected_value or a block"
    end
  end

  private

  def parsed_json
    @parsed_json ||= ActiveSupport::JSON.decode(response.body)
  end
end
