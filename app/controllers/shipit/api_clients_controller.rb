module Shipit
  class ApiClientsController < ShipitController
    include Pagination

    def index
      paginator = paginate(ApiClient.order(created_at: :desc).all)
      @api_clients = paginator.to_a
      @links = paginator.links
    end

    def new
      @api_client = ApiClient.new
    end

    def create
      @api_client = ApiClient.new(create_params.merge(creator_id: current_user.id))
      unless @api_client.save
        flash[:warning] = @api_client.errors.full_messages.to_sentence
      end

      respond_with(@api_client)
    end

    def show
      @api_client = ApiClient.find(params[:id])
    end

    def update
      @api_client = ApiClient.find(params[:id])
      options = if @api_client.update(update_params)
        {flash: {success: 'Successfully updated'}}
      else
        {flash: {warning: @stack.errors.full_messages.to_sentence}}
                end

      redirect_to(params[:return_to].presence || api_client_path(@api_client), options)
    end

    private

    def create_params
      params.require(:api_client).permit(:name, permissions: [])
    end

    def update_params
      params.require(:api_client).permit(permissions: [])
    end
  end
end
