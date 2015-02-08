class ApiController < ActionController::Base
  include ExplicitParameters

  params do
  end
  def index
    render json: params
  end

  params do
    requires :id, Integer
    accepts :count, Integer
    accepts :page_size, Integer, default: 100
  end
  def show
    render json: params
  end

end
