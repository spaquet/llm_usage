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
      if provider.last_sync_at && provider.last_sync_at > 5.minutes.ago
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
      synced_recently: active_providers.synced_recently.count,
      needs_sync: active_providers.needs_sync.count,
      healthy: active_providers.healthy.count,
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

  def refresh_provider_immediately(provider)
    client = create_api_client(provider)
    return false unless client&.test_connection

    usage_data = client.fetch_usage
    return false unless usage_data.present?

    # Update provider data immediately
    ActiveRecord::Base.transaction do
      update_provider_data(provider, usage_data)
    end

    true
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

  def update_provider_data(provider, usage_data)
    # Update plan
    plan = provider.plans.find_or_initialize_by(name: usage_data["plan_name"])
    plan.update!(details: usage_data["plan_details"])

    # Update usage record
    provider.usage_records.create!(
      user_id: usage_data["user_id"],
      request_count: usage_data["request_count"],
      timestamp: Time.current
    )

    # Update rate limits
    rate_limit = provider.rate_limits.first_or_initialize
    rate_limit.update!(
      limit: usage_data["rate_limit"],
      remaining: usage_data["rate_limit_remaining"],
      reset_at: parse_reset_time(usage_data["rate_limit_reset"])
    )

    # Update provider metadata
    provider.update_sync_metadata(usage_data)
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
      synced_at: provider.last_sync_at
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
    Provider.active.maximum(:last_sync_at)
  end

  def sync_jobs_running?
    # Check if there are any sync jobs currently running
    SolidQueue::Job.where(class_name: "SyncApiUsageJob")
                   .where(finished_at: nil)
                   .exists?
  end

  def parse_reset_time(reset_time_string)
    return 1.hour.from_now unless reset_time_string.present?

    begin
      if reset_time_string.is_a?(String)
        Time.parse(reset_time_string)
      else
        Time.at(reset_time_string.to_i)
      end
    rescue
      1.hour.from_now
    end
  end
end
