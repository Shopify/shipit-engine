# frozen_string_literal: true
module JSONHelper
  UNDEFINED = Object.new.freeze
  private_constant :UNDEFINED

  def assert_json(path = nil, expected_value = UNDEFINED, &block)
    assert_json_document(response.body, path, expected_value, &block)
  end

  def assert_json_document(document, path, expected_value = UNDEFINED)
    value = follow_path(path.to_s.split('.'), document: document)
    if block_given?
      yield value
    elsif expected_value == UNDEFINED
      raise ArgumentError, "Missing either expected_value or a block"
    elsif expected_value.nil?
      assert_nil(value)
    else
      assert_equal(expected_value, value)
    end
  end

  def assert_json_keys(path, keys = nil, document: response.body)
    if keys.nil?
      keys = path
      path = nil
    end

    value = follow_path(path.to_s.split('.'), document: document)
    case value
    when Hash
      assert_equal(keys.sort, value.keys.sort)
    else
      assert(false, "Expected #{path} to be a Hash, was: #{value.inspect}")
    end
  end

  def assert_no_json(path, document: response.body)
    segments = path.to_s.split('.')
    last_segment = segments.pop
    leaf = follow_path(segments, document: document)
    case leaf
    when Hash
      refute(leaf.key?(last_segment), "Expected #{leaf.inspect} not to include #{last_segment.inspect}")
    when Array
      refute(leaf.size > last_segment.to_i, "Expected #{leaf.inspect} to not have element at index #{last_segment.to_i}")
    else
      assert(false, "Expected #{leaf.inspect} to be a Hash or Array")
    end
  end

  private

  def follow_path(segments, document:)
    parsed_json = ActiveSupport::JSON.decode(document)
    segments.inject(parsed_json) do |object, key|
      case object
      when Hash
        assert_includes(object, key)
        object[key]
      when Array
        assert(object.size > key.to_i, "#{object.inspect} have no property #{key}")
        object[key.to_i]
      else
        assert(false, "Expected #{object.inspect} to be a Hash or Array")
      end
    end
  end
end
