class ApplicationController < ActionController::Base
  rescue_from LinkdingClient::UnconfiguredError, with: :handle_unconfigured_error

  private

  def handle_unconfigured_error(exception)
    Rails.logger.error(exception)
    render json: { error: exception.message }, status: :internal_server_error
  end
end
