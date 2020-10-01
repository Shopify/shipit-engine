# frozen_string_literal: true

module Shipit
  class RepositoriesController < ShipitController
    before_action :load_repository, only: %i(destroy settings update new_stack)

    def index
      @user_repositories = current_user.repositories_contributed_to

      @repositories = Repository.order(:owner, :name).to_a
    end

    def show
      @repository = Repository.from_param!(params[:id])

      @stacks = @repository.stacks

      @show_archived = params[:show_archived]
      @stacks = @stacks.not_archived unless @show_archived
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
      redirect_to(repositories_url)
    end

    def update
      options = {}
      unless @repository.update(update_params)
        options = { flash: { warning: @repository.errors.full_messages.to_sentence } }
      end

      redirect_to(params[:return_to].presence || repository_settings_path(@repository), options)
    end

    def settings
    end

    def new_stack
      @stack = @repository.stacks.new
      render("shipit/stacks/new")
    end

    private

    def create_params
      params.require(:repository).permit(:owner, :name)
    end

    def update_params
      params.require(:repository).permit(
        :review_stacks_enabled,
        :provisioning_behavior,
        :provisioning_label_name,
      )
    end

    def load_repository
      @repository = Repository.from_param!(params[:id])
    end
  end
end
