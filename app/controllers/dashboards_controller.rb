# app/controllers/dashboards_controller.rb
class DashboardsController < ApplicationController
  include Pagy::Backend

  def show
    @providers = Provider.includes(:plans, :usage_records, :rate_limits).active.load_async
    @pagy, @records = pagy(UsageRecord.includes(:provider).order(timestamp: :desc))
    @refresh_status = DashboardRefreshService.new.get_refresh_status
  end

  def refresh
    refresh_service = DashboardRefreshService.new(current_user)

    if params[:force] == "true"
      # Force refresh all providers
      result = refresh_service.force_refresh_all
      message = result[:message]
      notice_type = :notice
    else
      # Smart refresh (only providers that need it)
      results = refresh_service.refresh_all
      message = build_refresh_message(results)
      notice_type = results[:failed].any? ? :alert : :notice
    end

    respond_to do |format|
      format.html do
        redirect_to root_path, notice_type => message
      end

      format.json do
        render json: {
          message: message,
          refresh_status: refresh_service.get_refresh_status,
          timestamp: Time.current.iso8601
        }
      end
    end
  end

  def refresh_status
    refresh_service = DashboardRefreshService.new

    render json: {
      status: refresh_service.get_refresh_status,
      providers: Provider.active.map do |provider|
        {
          id: provider.id,
          name: provider.name,
          last_sync_at: provider.last_sync_at,
          sync_status: provider.sync_status,
          health: provider.healthy? ? "healthy" : "unhealthy",
          failure_count: provider.sync_failures_count
        }
      end
    }
  end

  private

  def build_refresh_message(results)
    success_count = results[:success].size
    failed_count = results[:failed].size
    skipped_count = results[:skipped].size

    messages = []

    if success_count > 0
      messages << "#{success_count} provider#{'s' if success_count != 1} refreshed successfully"
    end

    if skipped_count > 0
      messages << "#{skipped_count} provider#{'s' if skipped_count != 1} skipped"
    end

    if failed_count > 0
      failed_names = results[:failed].map { |r| r[:provider].name }.join(", ")
      messages << "#{failed_count} provider#{'s' if failed_count != 1} failed: #{failed_names}"
    end

    if messages.empty?
      "No providers needed refreshing"
    else
      messages.join(". ") + "."
    end
  end

  def current_user
    # Placeholder for user authentication
    # Replace with your actual user authentication logic
    nil
  end
end
