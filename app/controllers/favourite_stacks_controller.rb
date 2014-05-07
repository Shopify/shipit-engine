class FavouriteStacksController < ApplicationController
  before_action :load_favourite_stack, only: [:destroy]

  def create
    fs = FavouriteStack.new(stack_id: params[:stack_id], user: find_or_create_user)

    if fs.save
      fs.user.touch(:favourites_updated_at)
    else
      flash[:error] = fs.errors.to_a.first.to_s
    end

    redirect_back
  end

  def destroy
    @favourite_stack.destroy
    @favourite_stack.user.touch(:favourites_updated_at)

    redirect_back
  end

  private

  def redirect_back
    redirect_to request.referer || '/'
  end

  def load_favourite_stack
    @favourite_stack = FavouriteStack.where(user_id: find_or_create_user.id, stack_id: params[:stack_id]).first
  end

  def find_or_create_user
    User.where(email: session[:user][:email], name: session[:user][:name]).first_or_create
  end
end
