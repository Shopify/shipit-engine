class ApplicationController < ActionController::Base
  # Use basic auth for now
  if Rails.env.production?
    http_basic_authenticate_with :name => "shipit", :password => "yoloshipit"
  end

  # Respond to HTML by default
  respond_to :html

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
end
