# frozen_string_literal: true
module Shipit
  class TailTaskSerializer < ActiveModel::Serializer
    include ChunksHelper
    include ConditionalAttributes

    attributes :url, :status, :output, :rollback_url

    def url
      return @url if defined? @url
      @url = next_chunks_url(task)
    end

    def include_url?
      url.present?
    end

    def output
      task.tail_output(context[:last_id])
    end

    def rollback_url
      stack_deploy_path(stack, rollback)
    end

    def include_rollback_url?
      !rollback.nil?
    end

    private

    alias_method :task, :object
    delegate :stack, to: :object

    def rollback
      return @rollback if defined? @rollback
      @rollback = stack.rollbacks.where(parent_id: task.id).last
    end
  end
end
