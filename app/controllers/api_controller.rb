class ApiController < ActionController::Base
  include ExplicitParameters

  params do
  end
  def index
    render json: params
  end

  params do
    requires :id, Integer
    requires :author, User.where('id > 2')
    accepts :count, Integer
    accepts :page_size, Integer, default: 100
  end
  def show
    render json: params
  end

  private

  def active_users
    User.all
  end

end
