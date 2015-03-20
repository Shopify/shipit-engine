class OutputChunkSerializer < ActiveModel::Serializer
  attributes :id, :task_id, :text, :created_at, :updated_at
end
