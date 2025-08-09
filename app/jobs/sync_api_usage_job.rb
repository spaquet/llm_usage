class SyncApiUsageJob < ApplicationJob
 queue_as :default

 def perform
 Provider.where(status: :active).find_each do |provider|
 client = case provider.name
 when /xAI/i then XaiApiClient.new(provider)
 when /OpenAI/i then OpenaiApiClient.new(provider)
 when /Anthropic/i then AnthropicApiClient.new(provider)
 else next
 end

 usage_data = client.fetch_usage
 next unless usage_data.present?

 ActiveRecord::Base.transaction do
 provider.plans.find_or_create_by(name: usage_data["plan_name"]) do |plan|
 plan.details = usage_data["plan_details"]
 end

 provider.usage_records.create!(
 user_id: usage_data["user_id"],
 request_count: usage_data["request_count"],
 timestamp: Time.current
 )

 provider.rate_limits.find_or_create_by do |rate_limit|
 rate_limit.limit = usage_data["rate_limit"]
 rate_limit.remaining = usage_data["rate_limit_remaining"]
 rate_limit.reset_at = usage_data["rate_limit_reset"]
 end
 end
 end
 rescue => e
 Rails.logger.error("Usage sync error: #{e.message}")
 end
end
