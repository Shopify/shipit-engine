class ApplicationController < ActionController::Base
  # Respond to HTML by default
  respond_to :html
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
end
