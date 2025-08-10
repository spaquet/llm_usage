# app/components/enhanced_usage_card_component.rb
# frozen_string_literal: true

class EnhancedUsageCardComponent < ViewComponent::Base
  def initialize(provider:)
    @provider = provider
    @plan = provider.plans.last
    @usage = provider.usage_records.last
    @rate_limit = provider.rate_limits.last
    @monthly_usage = calculate_monthly_usage
    @monthly_limit = plan_monthly_limit
  end

  private

  attr_reader :provider, :plan, :usage, :rate_limit, :monthly_usage, :monthly_limit

  def calculate_monthly_usage
    # This should be calculated based on actual usage data
    # For now, returning mock data
    case provider.name.downcase
    when /claude|anthropic/
      120.0
    when /openai|gpt/
      180.0
    when /xai|grok/
      45.0
    else
      0.0
    end
  end

  def plan_monthly_limit
    # This should come from the plan details
    # For now, returning mock data
    case provider.name.downcase
    when /claude|anthropic/
      200.0
    when /openai|gpt/
      200.0
    when /xai|grok/
      100.0
    else
      100.0
    end
  end

  def usage_percentage
    return 0 if monthly_limit.zero?
    ((monthly_usage / monthly_limit) * 100).round(1)
  end

  def status_text
    percentage = usage_percentage
    case percentage
    when 0..60
      "active"
    when 61..85
      "near_limit"
    when 86..100
      "warning"
    else
      "suspended"
    end
  end

  def progress_bar_color
    percentage = usage_percentage
    case percentage
    when 0..60
      "bg-green-600"
    when 61..85
      "bg-yellow-500"
    when 86..100
      "bg-red-600"
    else
      "bg-red-600"
    end
  end

  # Move helper methods into component to avoid helpers. calls
  def provider_icon_class(provider_name)
    case provider_name.downcase
    when /claude|anthropic/
      "w-10 h-10 bg-orange-100 rounded-lg flex items-center justify-center"
    when /openai|gpt/
      "w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center"
    when /xai|grok/
      "w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center"
    else
      "w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center"
    end
  end

  def provider_icon_color(provider_name)
    case provider_name.downcase
    when /claude|anthropic/
      "text-orange-600"
    when /openai|gpt/
      "text-green-600"
    when /xai|grok/
      "text-blue-600"
    else
      "text-gray-600"
    end
  end

  def status_badge_class
    case status_text
    when "active"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
    when "near_limit"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
    when "warning"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
    when "suspended"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
    else
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    end
  end

  def format_currency(amount)
    return "$0.00" if amount.nil?
    "$#{sprintf('%.2f', amount)}"
  end

  def format_number(number)
    return "N/A" if number.nil?

    case number
    when 0..999
      number.to_s
    when 1000..999_999
      "#{(number / 1000.0).round(1)}K"
    when 1_000_000..999_999_999
      "#{(number / 1_000_000.0).round(1)}M"
    else
      "#{(number / 1_000_000_000.0).round(1)}B"
    end
  end

  def input_tokens
    # Mock data - should come from usage records
    case provider.name.downcase
    when /claude|anthropic/
      850_000
    when /openai|gpt/
      1_200_000
    when /xai|grok/
      450_000
    else
      0
    end
  end

  def output_tokens
    # Mock data - should come from usage records
    case provider.name.downcase
    when /claude|anthropic/
      280_000
    when /openai|gpt/
      320_000
    when /xai|grok/
      150_000
    else
      0
    end
  end

  def images_generated
    # Mock data - should come from usage records
    case provider.name.downcase
    when /openai|gpt/
      24
    when /xai|grok/
      12
    else
      0
    end
  end

  def requests_today
    # Mock data - should come from usage records
    usage&.request_count || rand(50..200)
  end

  def rate_limit_requests
    rate_limit&.remaining || rand(40..50)
  end

  def rate_limit_requests_max
    rate_limit&.limit || 50
  end

  def rate_limit_tokens
    # Mock data
    case provider.name.downcase
    when /claude|anthropic/
      38_000
    when /openai|gpt/
      149_000
    when /xai|grok/
      28_000
    else
      10_000
    end
  end

  def rate_limit_tokens_max
    # Mock data
    case provider.name.downcase
    when /claude|anthropic/
      40_000
    when /openai|gpt/
      150_000
    when /xai|grok/
      30_000
    else
      10_000
    end
  end

  def rate_limit_status(current, max)
    percentage = (current.to_f / max.to_f) * 100
    case percentage
    when 0..70
      "text-green-600"
    when 71..90
      "text-yellow-600"
    else
      "text-red-600"
    end
  end

  def warning_message
    percentage = usage_percentage
    case percentage
    when 86..95
      "⚠️ Approaching limit"
    when 96..100
      "🚨 At usage limit"
    when 101..Float::INFINITY
      "🛑 Over usage limit"
    else
      nil
    end
  end

  def days_until_reset
    # Mock data - should calculate based on plan reset date
    rand(8..15)
  end
end
