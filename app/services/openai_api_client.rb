# app/services/openai_api_client.rb
class OpenaiApiClient
  include HTTParty
  base_uri "https://api.openai.com"

  def initialize(provider)
    @provider = provider
    @headers = {
      "Authorization" => "Bearer #{@provider.api_key}",
      "Content-Type" => "application/json"
    }
  end

  def fetch_usage
    begin
      # Get usage data from OpenAI
      usage_data = get_usage_data
      billing_data = get_billing_data
      rate_limits = get_rate_limits

      {
        "plan_name" => billing_data["plan"] || "Pay-as-you-go",
        "plan_details" => {
          "hard_limit_usd" => billing_data["hard_limit_usd"],
          "soft_limit_usd" => billing_data["soft_limit_usd"],
          "system_hard_limit_usd" => billing_data["system_hard_limit_usd"],
          "access_until" => billing_data["access_until"]
        },
        "user_id" => 1,
        "request_count" => calculate_daily_requests(usage_data),
        "input_tokens" => calculate_total_tokens(usage_data, "prompt"),
        "output_tokens" => calculate_total_tokens(usage_data, "completion"),
        "images_generated" => calculate_images_generated(usage_data),
        "rate_limit" => rate_limits["requests_per_minute"],
        "rate_limit_remaining" => rate_limits["remaining_requests"],
        "rate_limit_reset" => rate_limits["reset_time"],
        "monthly_usage_cost" => billing_data["total_usage"] || 0.0,
        "monthly_limit_cost" => billing_data["hard_limit_usd"] || 200.0
      }
    rescue => e
      Rails.logger.error("OpenAI API error: #{e.message}")
      fallback_usage_data
    end
  end

  def test_connection
    begin
      response = self.class.get("/v1/models", headers: @headers)
      response.success?
    rescue => e
      Rails.logger.error("OpenAI connection test failed: #{e.message}")
      false
    end
  end

  private

  def get_usage_data
    # Get usage for the current month
    start_date = Date.current.beginning_of_month.strftime("%Y-%m-%d")
    end_date = Date.current.strftime("%Y-%m-%d")

    response = self.class.get("/v1/usage",
      headers: @headers,
      query: {
        start_date: start_date,
        end_date: end_date
      }
    )

    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.warn("OpenAI usage API returned #{response.code}: #{response.body}")
      { "data" => [] }
    end
  end

  def get_billing_data
    response = self.class.get("/v1/dashboard/billing/subscription", headers: @headers)

    if response.success?
      subscription_data = JSON.parse(response.body)

      # Get current usage
      usage_response = self.class.get("/v1/dashboard/billing/usage",
        headers: @headers,
        query: {
          start_date: Date.current.beginning_of_month.strftime("%Y-%m-%d"),
          end_date: Date.current.strftime("%Y-%m-%d")
        }
      )

      usage_data = usage_response.success? ? JSON.parse(usage_response.body) : {}

      subscription_data.merge(usage_data)
    else
      Rails.logger.warn("OpenAI billing API returned #{response.code}: #{response.body}")
      {
        "plan" => "Unknown",
        "hard_limit_usd" => 200.0,
        "total_usage" => 0.0
      }
    end
  end

  def get_rate_limits
    # OpenAI includes rate limit info in response headers
    # Make a simple request to get current rate limit status
    begin
      response = self.class.get("/v1/models", headers: @headers.merge({ "limit" => "1" }))

      {
        "requests_per_minute" => response.headers["x-ratelimit-limit-requests"]&.to_i || 3000,
        "remaining_requests" => response.headers["x-ratelimit-remaining-requests"]&.to_i || 2950,
        "tokens_per_minute" => response.headers["x-ratelimit-limit-tokens"]&.to_i || 150000,
        "remaining_tokens" => response.headers["x-ratelimit-remaining-tokens"]&.to_i || 149000,
        "reset_time" => response.headers["x-ratelimit-reset-requests"] || 1.minute.from_now.iso8601
      }
    rescue => e
      Rails.logger.warn("Could not fetch OpenAI rate limits: #{e.message}")
      {
        "requests_per_minute" => 3000,
        "remaining_requests" => 2950,
        "tokens_per_minute" => 150000,
        "remaining_tokens" => 149000,
        "reset_time" => 1.minute.from_now.iso8601
      }
    end
  end

  def calculate_daily_requests(usage_data)
    daily_data = usage_data.dig("data")&.find { |d| d["date"] == Date.current.strftime("%Y-%m-%d") }
    return 0 unless daily_data

    daily_data["n_requests"] || 0
  end

  def calculate_total_tokens(usage_data, token_type)
    return 0 unless usage_data["data"]

    usage_data["data"].sum do |day_data|
      day_data["#{token_type}_tokens"] || 0
    end
  end

  def calculate_images_generated(usage_data)
    return 0 unless usage_data["data"]

    usage_data["data"].sum do |day_data|
      # Look for DALL-E usage
      day_data["n_generated_images"] || 0
    end
  end

  def fallback_usage_data
    {
      "plan_name" => "Unknown",
      "plan_details" => {},
      "user_id" => 1,
      "request_count" => 0,
      "input_tokens" => 0,
      "output_tokens" => 0,
      "images_generated" => 0,
      "rate_limit" => 3000,
      "rate_limit_remaining" => 3000,
      "rate_limit_reset" => 1.minute.from_now,
      "monthly_usage_cost" => 0.0,
      "monthly_limit_cost" => 200.0
    }
  end
end
