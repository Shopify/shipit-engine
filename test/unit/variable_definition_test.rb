# frozen_string_literal: true

require 'test_helper'

module Shipit
  class VariableDefinitionTest < ActiveSupport::TestCase
    setup do
      @attributes = {
        "name" => "Variable name",
        "title" => "Variable title",
        "default" => "Variable default",
      }
      @select = %w(var1 var2 var3)
    end

    test "#initialize sets up the expected values" do
      subject = Shipit::VariableDefinition.new(@attributes)

      assert_equal "Variable name", subject.name
      assert_equal "Variable title", subject.title
      assert_equal "Variable default", subject.default
      assert_nil subject.select
      assert subject.default_provided?
    end

    test "#initialize name is required" do
      assert_raises KeyError do
        @attributes.delete("name")
        Shipit::VariableDefinition.new(@attributes)
      end
    end

    test "#initialize stringifies the default" do
      @attributes["default"] = :value
      subject = Shipit::VariableDefinition.new(@attributes)

      assert_equal "value", subject.default
    end

    test "#initialize sets the select if present" do
      @attributes["select"] = @select
      subject = Shipit::VariableDefinition.new(@attributes)

      assert_equal @select, subject.select
    end

    test "#initialize sets nil for select if the array is empty" do
      @attributes["select"] = []
      subject = Shipit::VariableDefinition.new(@attributes)

      assert_nil subject.select
    end

    test "#default_provided?" do
      attributes = {
        "name" => "Variable name",
        "title" => "Variable title",
      }
      subject = Shipit::VariableDefinition.new(attributes)
      refute subject.default_provided?
    end

    test "#to_h returns hash version" do
      assert_equal @attributes.merge("select" => nil), Shipit::VariableDefinition.new(@attributes).to_h
    end

    test "#to_h returns hash version that includes select" do
      assert_equal @attributes.merge("select" => @select), Shipit::VariableDefinition.new(@attributes.merge("select" => @select)).to_h
    end
  end
end
