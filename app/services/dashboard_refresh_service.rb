# app/services/dashboard_refresh_service.rb
class DashboardRefreshService
  def initialize(user = nil)
    @user = user
  end

  def refresh_all
    results = {
      success: [],
      failed: [],
      skipped: []
    }

    Provider.active.find_each do |provider|
      result = refresh_provider(provider)
      results[result[:status]] << result
    end

    # Trigger async refresh for any providers that need it
    schedule_additional_syncs(results)

    results
  end

  def refresh_provider(provider)
    return skip_result(provider, "Provider not active") unless provider.active?
    return skip_result(provider, "Missing API credentials") unless provider.can_sync?

    begin
      # Check if provider was synced recently to avoid rate limiting
      if provider.respond_to?(:last_sync_at) && provider.last_sync_at && provider.last_sync_at > 5.minutes.ago
        return skip_result(provider, "Recently synced")
      end

      # Perform immediate sync
      SyncApiUsageJob.perform_now(provider.id)

      success_result(provider)
    rescue => e
      Rails.logger.error("Dashboard refresh failed for #{provider.name}: #{e.message}")
      failed_result(provider, e.message)
    end
  end

  def get_refresh_status
    active_providers = Provider.active.includes(:rate_limits, :usage_records, :plans)

    {
      total_providers: active_providers.count,
      synced_recently: synced_recently_count(active_providers),
      needs_sync: needs_sync_count(active_providers),
      healthy: healthy_count(active_providers),
      last_global_sync: last_global_sync_time,
      sync_in_progress: sync_jobs_running?
    }
  end

  def force_refresh_all
    # Force refresh all providers regardless of last sync time
    Provider.active.find_each do |provider|
      SyncApiUsageJob.perform_later(provider.id)
    end

    {
      message: "Forced refresh scheduled for all active providers",
      providers_count: Provider.active.count
    }
  end

  private

  def synced_recently_count(providers)
    if Provider.column_names.include?("last_sync_at")
      providers.where("last_sync_at > ?", 1.hour.ago).count
    else
      0
    end
  end

  def needs_sync_count(providers)
    if Provider.column_names.include?("last_sync_at")
      providers.where("last_sync_at IS NULL OR last_sync_at < ?", 15.minutes.ago).count
    else
      providers.count # All providers need sync if no tracking
    end
  end

  def healthy_count(providers)
    if Provider.column_names.include?("sync_failures_count")
      providers.where(sync_failures_count: 0..2).count
    else
      providers.count # Assume all healthy if no tracking
    end
  end

  def create_api_client(provider)
    case provider.provider_type&.downcase
    when "xai"
      XaiApiClient.new(provider)
    when "openai"
      OpenaiApiClient.new(provider)
    when "anthropic"
      AnthropicApiClient.new(provider)
    else
      nil
    end
  end

  def schedule_additional_syncs(results)
    failed_providers = results[:failed].map { |r| r[:provider] }

    # Retry failed syncs after a delay
    failed_providers.each do |provider|
      SyncApiUsageJob.set(wait: 2.minutes).perform_later(provider.id)
    end
  end

  def success_result(provider)
    {
      status: :success,
      provider: provider,
      message: "Successfully refreshed #{provider.name}",
      synced_at: provider.respond_to?(:last_sync_at) ? provider.last_sync_at : Time.current
    }
  end

  def failed_result(provider, error_message)
    {
      status: :failed,
      provider: provider,
      message: "Failed to refresh #{provider.name}: #{error_message}",
      error: error_message
    }
  end

  def skip_result(provider, reason)
    {
      status: :skipped,
      provider: provider,
      message: "Skipped #{provider.name}: #{reason}",
      reason: reason
    }
  end

  def last_global_sync_time
    if Provider.column_names.include?("last_sync_at")
      Provider.active.maximum(:last_sync_at)
    else
      nil
    end
  end

  def sync_jobs_running?
    # Check if we can access job information
    return false unless solid_queue_tables_exist?

    begin
      SolidQueue::Job.where(class_name: "SyncApiUsageJob")
                     .where(finished_at: nil)
                     .exists?
    rescue => e
      Rails.logger.debug("Could not check job status: #{e.message}")
      false
    end
  end

  def solid_queue_tables_exist?
    return false unless defined?(SolidQueue)

    begin
      # Check if the table exists in the current database connection
      ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")
    rescue => e
      Rails.logger.debug("SolidQueue tables not available: #{e.message}")
      false
    end
  end
end
