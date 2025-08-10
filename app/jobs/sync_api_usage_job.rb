# app/jobs/sync_api_usage_job.rb
class SyncApiUsageJob < ApplicationJob
  queue_as :default

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(provider_id = nil)
    providers = provider_id ? [Provider.find(provider_id)] : Provider.where(status: :active)

    providers.find_each do |provider|
      sync_provider_usage(provider)
    end
  end

  private

  def sync_provider_usage(provider)
    Rails.logger.info("Syncing usage for provider: #{provider.name}")

    begin
      client = create_api_client(provider)
      return unless client

      # Test connection first
      unless client.test_connection
        Rails.logger.error("Connection test failed for #{provider.name}")
        provider.update(status: :suspended)
        return
      end

      # Fetch usage data
      usage_data = client.fetch_usage
      return unless usage_data.present?

      # Update provider status to active if it was suspended
      provider.update(status: :active) if provider.suspended?

      ActiveRecord::Base.transaction do
        # Update or create plan
        update_plan(provider, usage_data)

        # Create usage record
        create_usage_record(provider, usage_data)

        # Update rate limits
        update_rate_limits(provider, usage_data)

        # Update provider with additional metadata
        update_provider_metadata(provider, usage_data)
      end

      Rails.logger.info("Successfully synced usage for #{provider.name}")

    rescue => e
      Rails.logger.error("Error syncing #{provider.name}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      # Mark provider as suspended after repeated failures
      increment_failure_count(provider)
    end
  end

  def create_api_client(provider)
    case provider.provider_type&.downcase
    when 'xai'
      XaiApiClient.new(provider)
    when 'openai'
      OpenaiApiClient.new(provider)
    when 'anthropic'
      AnthropicApiClient.new(provider)
    else
      Rails.logger.warn("Unknown provider type: #{provider.provider_type}")
      nil
    end
  end

  def update_plan(provider, usage_data)
    plan = provider.plans.find_or_initialize_by(name: usage_data["plan_name"])

    plan.update!(
      details: usage_data["plan_details"].merge({
        "last_updated" => Time.current.iso8601,
        "monthly_limit" => usage_data["monthly_limit_cost"],
        "currency" => "USD"
      })
    )
  end

  def create_usage_record(provider, usage_data)
    # Create a new usage record for today
    today = Date.current

    existing_record = provider.usage_records.find_by(
      timestamp: today.beginning_of_day..today.end_of_day
    )

    if existing_record
      # Update existing record
      existing_record.update!(
        request_count: usage_data["request_count"],
        user_id: usage_data["user_id"],
        timestamp: Time.current
      )
    else
      # Create new record
      provider.usage_records.create!(
        user_id: usage_data["user_id"],
        request_count: usage_data["request_count"],
        timestamp: Time.current
      )
    end
  end

  def update_rate_limits(provider, usage_data)
    rate_limit = provider.rate_limits.first_or_initialize

    rate_limit.update!(
      limit: usage_data["rate_limit"],
      remaining: usage_data["rate_limit_remaining"],
      reset_at: parse_reset_time(usage_data["rate_limit_reset"])
    )
  end

  def update_provider_metadata(provider, usage_data)
    # Use the new metadata system
    provider.update_sync_metadata(usage_data)
    Rails.logger.info("Updated metadata for #{provider.name}")
  end

  def increment_failure_count(provider)
    provider.increment_sync_failures!
    Rails.logger.error("Sync failure #{provider.sync_failures_count} for #{provider.name}")
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
