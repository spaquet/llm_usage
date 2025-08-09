class XaiApiClient
 include HTTParty

 def initialize(provider)
 @provider = provider
 self.class.base_uri provider.api_url
 @headers = { "Authorization" => "Bearer #{@provider.api_key}" }
 end

 def fetch_usage
 response = self.class.get("/#{@provider.api_version || 'v1'}/usage", headers: @headers)
 JSON.parse(response.body)
 rescue => e
 Rails.logger.error("xAI API error: #{e.message}")
 {}
 end
end
