class DashboardsController < ApplicationController
  include Pagy::Backend

  def show
    @providers = Provider.includes(:plans, :usage_records, :rate_limits).load_async
    @pagy, @records = pagy(UsageRecord.order(timestamp: :desc))
  end

  def refresh
    SyncApiUsageJob.perform_later
    redirect_to root_path, notice: "Usage data refresh scheduled."
  end
end
