# app/helpers/dashboards_helper.rb
module DashboardsHelper
  def calculate_today_usage
    # Calculate real usage from today's records
    today_records = UsageRecord.joins(:provider)
                              .where(providers: { status: :active })
                              .where(timestamp: Date.current.beginning_of_day..Date.current.end_of_day)

    # Sum up costs from provider metadata or estimate from requests
    total_cost = 0.0

    @providers.each do |provider|
      provider_records = today_records.where(provider: provider)
      requests = provider_records.sum(:request_count)

      # Get cost from provider metadata or estimate
      cost_per_request = get_cost_per_request(provider)
      total_cost += requests * cost_per_request
    end

    total_cost
  end

  def calculate_usage_change
    # Compare today vs yesterday
    today_usage = calculate_today_usage
    yesterday_usage = calculate_yesterday_usage

    return 0 if yesterday_usage.zero?

    ((today_usage - yesterday_usage) / yesterday_usage * 100).round(1)
  end

  def calculate_total_tokens
    # Get actual token counts from provider metadata
    total_input = 0
    total_output = 0

    @providers.each do |provider|
      plan = provider.plans.last
      if plan&.details
        total_input += plan.details["input_tokens"]&.to_i || 0
        total_output += plan.details["output_tokens"]&.to_i || 0
      else
        # Estimate from usage records
        monthly_requests = get_monthly_requests(provider)
        total_input += monthly_requests * 850 # Average input tokens
        total_output += monthly_requests * 280 # Average output tokens
      end
    end

    total_input + total_output
  end

  def calculate_input_tokens
    total_input = 0

    @providers.each do |provider|
      plan = provider.plans.last
      if plan&.details&.dig("input_tokens")
        total_input += plan.details["input_tokens"].to_i
      else
        # Estimate from usage
        monthly_requests = get_monthly_requests(provider)
        total_input += monthly_requests * 850
      end
    end

    total_input
  end

  def calculate_output_tokens
    total_output = 0

    @providers.each do |provider|
      plan = provider.plans.last
      if plan&.details&.dig("output_tokens")
        total_output += plan.details["output_tokens"].to_i
      else
        # Estimate from usage
        monthly_requests = get_monthly_requests(provider)
        total_output += monthly_requests * 280
      end
    end

    total_output
  end

  def overall_rate_limit_status
    # Check actual rate limits from providers
    critical_providers = @providers.select do |provider|
      rate_limit = provider.rate_limits.last
      next false unless rate_limit

      usage_percentage = if rate_limit.limit > 0
        ((rate_limit.limit - rate_limit.remaining).to_f / rate_limit.limit.to_f) * 100
      else
        0
      end

      usage_percentage > 80 # Consider >80% as critical
    end

    if critical_providers.any?
      critical_providers.size > (@providers.size / 2) ? "Critical" : "Warning"
    else
      "Good"
    end
  end

  def rate_limit_status_color
    case overall_rate_limit_status
    when "Good"
      "green"
    when "Warning"
      "yellow"
    when "Critical"
      "red"
    else
      "gray"
    end
  end

  def calculate_total_images_generated
    total_images = 0

    @providers.each do |provider|
      plan = provider.plans.last
      if plan&.details&.dig("images_generated")
        total_images += plan.details["images_generated"].to_i
      end
    end

    total_images
  end

  def get_provider_health_status(provider)
    # Determine provider health based on multiple factors
    rate_limit = provider.rate_limits.last
    recent_usage = provider.usage_records.where("timestamp > ?", 1.hour.ago).exists?

    if provider.suspended?
      "suspended"
    elsif rate_limit&.remaining && rate_limit.limit > 0
      usage_percentage = ((rate_limit.limit - rate_limit.remaining).to_f / rate_limit.limit.to_f) * 100
      if usage_percentage > 90
        "critical"
      elsif usage_percentage > 80
        "warning"
      else
        "healthy"
      end
    elsif recent_usage
      "healthy"
    else
      "unknown"
    end
  end

  def format_last_sync_time(provider)
    plan = provider.plans.last
    if plan&.details&.dig("last_updated")
      time = Time.parse(plan.details["last_updated"])
      time_ago_in_words(time) + " ago"
    else
      "Never"
    end
  end

  private

  def calculate_yesterday_usage
    yesterday_records = UsageRecord.joins(:provider)
                                 .where(providers: { status: :active })
                                 .where(timestamp: 1.day.ago.beginning_of_day..1.day.ago.end_of_day)

    total_cost = 0.0

    @providers.each do |provider|
      provider_records = yesterday_records.where(provider: provider)
      requests = provider_records.sum(:request_count)

      cost_per_request = get_cost_per_request(provider)
      total_cost += requests * cost_per_request
    end

    total_cost
  end

  def get_cost_per_request(provider)
    # Get cost per request from provider metadata or use defaults
    plan = provider.plans.last
    if plan&.details&.dig("cost_per_request")
      plan.details["cost_per_request"].to_f
    else
      # Default cost estimates per request by provider type
      case provider.provider_type&.downcase
      when "anthropic"
        0.01
      when "openai"
        0.015
      when "xai"
        0.008
      else
        0.01
      end
    end
  end

  def get_monthly_requests(provider)
    provider.usage_records
           .where(timestamp: Date.current.beginning_of_month..Date.current.end_of_month)
           .sum(:request_count)
  end
end
