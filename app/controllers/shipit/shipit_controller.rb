# frozen_string_literal: true

module Shipit
  class ShipitController < ApplicationController
    layout 'shipit'

    helper GithubUrlHelper
    helper StacksHelper
    helper TasksHelper
    helper DeploysHelper
    helper ChunksHelper

    helper Shipit::Engine.routes.url_helpers
    include Shipit::Engine.routes.url_helpers

    before_action :ensure_required_settings

    include Shipit::Authentication

    # Respond to HTML by default
    respond_to :html

    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    protect_from_forgery with: :exception

    private

    def ensure_required_settings
      return if Shipit.all_settings_present?

      render('shipit/missing_settings')
    end
  end
end
