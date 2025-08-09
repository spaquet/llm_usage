class AnthropicApiClient
  include HTTParty
  base_uri "https://api.anthropic.com"

  def initialize(provider)
    @provider = provider
    @headers = { "x-api-key" => @provider.api_key }
  end

  def fetch_usage
    response = self.class.get("/v1/usage", headers: @headers)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error("Anthropic API error: #{e.message}")
    {}
  end
end
