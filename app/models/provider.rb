class Provider < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :usage_records, dependent: :destroy
  has_many :rate_limits, dependent: :destroy

  encrypts :api_key, deterministic: true
  encrypts :api_secret, deterministic: true

  PREDEFINED_PROVIDERS = {
  "xAI" => { api_url: "https://api.x.ai", key_field: :api_key, api_version: "v1" },
  "OpenAI" => { api_url: "https://api.openai.com", key_field: :api_key, api_version: "v1" },
  "Anthropic" => { api_url: "https://api.anthropic.com", key_field: :api_key, api_version: "v1" }
  }.freeze

  enum :status, { active: 0, inactive: 1, suspended: 2 }
end
