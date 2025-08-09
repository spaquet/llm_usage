class OpenaiApiClient
  include HTTParty
  base_uri "https://api.openai.com"

  def initialize(provider)
    @provider = provider
    @headers = { "Authorization" => "Bearer #{@provider.api_key}" }
  end

  def fetch_usage
    response = self.class.get("/v1/usage", headers: @headers)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error("OpenAI API error: #{e.message}")
    {}
  end
end
