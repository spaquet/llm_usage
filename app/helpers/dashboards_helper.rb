# app/helpers/dashboards_helper.rb
module DashboardsHelper
  def calculate_today_usage
    # Mock calculation - should be based on actual usage records
    @providers.sum do |provider|
      case provider.name.downcase
      when /claude|anthropic/
        8.50
      when /openai|gpt/
        12.30
      when /xai|grok/
        4.00
      else
        0.0
      end
    end
  end

  def calculate_usage_change
    # Mock calculation - should compare today vs yesterday
    rand(-5..15)
  end

  def calculate_total_tokens
    @providers.sum do |provider|
      case provider.name.downcase
      when /claude|anthropic/
        1_130_000
      when /openai|gpt/
        1_520_000
      when /xai|grok/
        600_000
      else
        0
      end
    end
  end

  def calculate_input_tokens
    @providers.sum do |provider|
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
  end

  def calculate_output_tokens
    @providers.sum do |provider|
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
  end

  def overall_rate_limit_status
    # Mock logic - should check actual rate limits
    critical_providers = @providers.select do |provider|
      case provider.name.downcase
      when /openai|gpt/
        true # Mock: OpenAI is near limit
      else
        false
      end
    end

    if critical_providers.any?
      "Warning"
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
end
