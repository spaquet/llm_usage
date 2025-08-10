# app/services/xai_api_client.rb
class XaiApiClient
  include HTTParty

  def initialize(provider)
    @provider = provider
    self.class.base_uri provider.api_url
    @headers = {
      "Authorization" => "Bearer #{@provider.api_key}",
      "Content-Type" => "application/json"
    }
  end

  def fetch_usage
    begin
      # xAI API structure (similar to OpenAI but different endpoints)
      usage_data = get_usage_data
      billing_data = get_billing_data
      rate_limits = get_rate_limits

      {
        "plan_name" => billing_data["plan"] || "Grok Premium",
        "plan_details" => {
          "model_access" => ["grok-beta"],
          "monthly_limit" => billing_data["monthly_limit"] || 100.0,
          "billing_cycle" => billing_data["billing_cycle"]
        },
        "user_id" => 1,
        "request_count" => calculate_daily_requests(usage_data),
        "input_tokens" => calculate_total_tokens(usage_data, "input"),
        "output_tokens" => calculate_total_tokens(usage_data, "output"),
        "images_generated" => calculate_images_generated(usage_data),
        "rate_limit" => rate_limits["requests_per_minute"],
        "rate_limit_remaining" => rate_limits["remaining_requests"],
        "rate_limit_reset" => rate_limits["reset_time"],
        "monthly_usage_cost" => billing_data["current_usage"] || 0.0,
        "monthly_limit_cost" => billing_data["monthly_limit"] || 100.0
      }
    rescue => e
      Rails.logger.error("xAI API error: #{e.message}")
      fallback_usage_data
    end
  end

  def test_connection
    begin
      response = self.class.get("/#{@provider.api_version || 'v1'}/models", headers: @headers)
      response.success?
    rescue => e
      Rails.logger.error("xAI connection test failed: #{e.message}")
      false
    end
  end

  private

  def get_usage_data
    # Get usage for the current month
    start_date = Date.current.beginning_of_month.strftime("%Y-%m-%d")
    end_date = Date.current.strftime("%Y-%m-%d")

    response = self.class.get("/#{@provider.api_version || 'v1'}/usage",
      headers: @headers,
      query: {
        start_date: start_date,
        end_date: end_date
      }
    )

    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.warn("xAI usage API returned #{response.code}: #{response.body}")
      { "usage_data" => [] }
    end
  end

  def get_billing_data
    response = self.class.get("/#{@provider.api_version || 'v1'}/billing", headers: @headers)

    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.warn("xAI billing API returned #{response.code}: #{response.body}")
      {
        "plan" => "Grok Premium",
        "monthly_limit" => 100.0,
        "current_usage" => 0.0
      }
    end
  end

  def get_rate_limits
    # xAI includes rate limit info in response headers (similar to OpenAI)
    begin
      response = self.class.get("/#{@provider.api_version || 'v1'}/models", headers: @headers)

      {
        "requests_per_minute" => response.headers["x-ratelimit-limit-requests"]&.to_i || 1000,
        "remaining_requests" => response.headers["x-ratelimit-remaining-requests"]&.to_i || 950,
        "tokens_per_minute" => response.headers["x-ratelimit-limit-tokens"]&.to_i || 30000,
        "remaining_tokens" => response.headers["x-ratelimit-remaining-tokens"]&.to_i || 28000,
        "reset_time" => response.headers["x-ratelimit-reset-requests"] || 1.minute.from_now.iso8601
      }
    rescue => e
      Rails.logger.warn("Could not fetch xAI rate limits: #{e.message}")
      {
        "requests_per_minute" => 1000,
        "remaining_requests" => 950,
        "tokens_per_minute" => 30000,
        "remaining_tokens" => 28000,
        "reset_time" => 1.minute.from_now.iso8601
      }
    end
  end

  def calculate_daily_requests(usage_data)
    daily_data = usage_data.dig("usage_data")&.find { |d| d["date"] == Date.current.strftime("%Y-%m-%d") }
    return 0 unless daily_data

    daily_data["requests"] || 0
  end

  def calculate_total_tokens(usage_data, token_type)
    return 0 unless usage_data["usage_data"]

    usage_data["usage_data"].sum do |day_data|
      day_data["#{token_type}_tokens"] || 0
    end
  end

  def calculate_images_generated(usage_data)
    return 0 unless usage_data["usage_data"]

    usage_data["usage_data"].sum do |day_data|
      day_data["images_generated"] || 0
    end
  end

  def fallback_usage_data
    {
      "plan_name" => "Grok Premium",
      "plan_details" => {},
      "user_id" => 1,
      "request_count" => 0,
      "input_tokens" => 0,
      "output_tokens" => 0,
      "images_generated" => 0,
      "rate_limit" => 1000,
      "rate_limit_remaining" => 1000,
      "rate_limit_reset" => 1.minute.from_now,
      "monthly_usage_cost" => 0.0,
      "monthly_limit_cost" => 100.0
    }
  end
end
