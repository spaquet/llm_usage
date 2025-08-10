# app/jobs/provider_health_check_job.rb
class ProviderHealthCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting daily provider health check")

    Provider.all.find_each do |provider|
      check_provider_health(provider)
    end

    Rails.logger.info("Completed daily provider health check")
  end

  private

  def check_provider_health(provider)
    health_issues = []

    # Check if provider hasn't been synced recently
    if provider.last_sync_at.nil?
      health_issues << "Never synced"
    elsif provider.last_sync_at < 4.hours.ago
      health_issues << "Sync is stale (last sync: #{time_ago_in_words(provider.last_sync_at)} ago)"
    end

    # Check failure count
    if provider.sync_failures_count > 3
      health_issues << "High failure count (#{provider.sync_failures_count} failures)"
    end

    # Check rate limits
    rate_limit = provider.rate_limits.last
    if rate_limit && rate_limit.remaining == 0
      health_issues << "Rate limit exhausted"
    end

    # Check monthly usage
    if provider.usage_percentage > 90
      health_issues << "Monthly usage at #{provider.usage_percentage}%"
    end

    # Check if provider is active but hasn't had any usage
    if provider.active? && provider.monthly_requests == 0
      health_issues << "No usage recorded this month"
    end

    # Log health status
    if health_issues.any?
      Rails.logger.warn("Provider #{provider.name} health issues: #{health_issues.join(', ')}")

      # Auto-suspend providers with critical issues
      critical_issues = health_issues.select { |issue| issue.include?("Rate limit exhausted") || issue.include?("High failure count") }
      if critical_issues.any? && provider.active?
        provider.update!(status: :suspended)
        Rails.logger.error("Auto-suspended provider #{provider.name} due to: #{critical_issues.join(', ')}")
      end
    else
      Rails.logger.info("Provider #{provider.name} is healthy")

      # Auto-reactivate suspended providers that are now healthy
      if provider.suspended? && provider.sync_failures_count < 3
        provider.update!(status: :active)
        Rails.logger.info("Auto-reactivated provider #{provider.name}")
      end
    end
  end
end
