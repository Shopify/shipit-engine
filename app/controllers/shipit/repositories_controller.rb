module Shipit
  class RepositoriesController < ShipitController
    before_action :load_repository, only: %i(destroy settings)

    def index
      @user_repositories = current_user.repositories_contributed_to

      @repositories = Repository.order(:owner, :name).to_a
    end

    def show
      @repository = Repository.from_param!(params[:id])

      @stacks = @repository.stacks
    end

    def create
      @repository = Repository.new(create_params)
      unless @repository.save
        flash[:warning] = @repository.errors.full_messages.to_sentence
      end
      respond_with(@repository)
    end

    def new
      @repository = Repository.new
    end

    def destroy
      @repository.schedule_for_destroy!
      redirect_to repositories_url
    end

    def settings
    end

    private

    def create_params
      params.require(:repository).permit(:owner, :name)
    end

    def load_repository
      @repository = Repository.from_param!(params[:id])
    end
  end
end
