# app/models/provider.rb
class Provider < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :usage_records, dependent: :destroy
  has_many :rate_limits, dependent: :destroy

  encrypts :api_key, deterministic: true
  encrypts :api_secret, deterministic: true

  validates :name, presence: true
  validates :api_key, presence: true
  validates :api_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :provider_type, presence: true

  PREDEFINED_PROVIDERS = {
    "xAI" => { api_url: "https://api.x.ai", key_field: :api_key, api_version: "v1" },
    "OpenAI" => { api_url: "https://api.openai.com", key_field: :api_key, api_version: "v1" },
    "Anthropic" => { api_url: "https://api.anthropic.com", key_field: :api_key, api_version: "v1" }
  }.freeze

  enum :status, { active: 0, inactive: 1, suspended: 2 }

  # Scopes
  scope :synced_recently, -> { where("last_sync_at > ?", 1.hour.ago) }
  scope :needs_sync, -> { where("last_sync_at IS NULL OR last_sync_at < ?", 15.minutes.ago) }
  scope :healthy, -> { where(sync_failures_count: 0..2) }

  # Callbacks
  before_validation :set_default_api_secret, if: -> { api_secret.blank? }
  after_create :schedule_initial_sync

  # Metadata accessors
  def monthly_usage_cost
    metadata["monthly_usage_cost"]&.to_f || 0.0
  end

  def monthly_limit_cost
    metadata["monthly_limit_cost"]&.to_f || default_monthly_limit
  end

  def input_tokens
    metadata["input_tokens"]&.to_i || 0
  end

  def output_tokens
    metadata["output_tokens"]&.to_i || 0
  end

  def images_generated
    metadata["images_generated"]&.to_i || 0
  end

  def usage_percentage
    return 0 if monthly_limit_cost.zero?
    ((monthly_usage_cost / monthly_limit_cost) * 100).round(1)
  end

  def sync_status
    if last_sync_at.nil?
      "never_synced"
    elsif last_sync_at < 1.hour.ago
      "stale"
    elsif sync_failures_count > 3
      "failing"
    else
      "current"
    end
  end

  def healthy?
    sync_failures_count < 3 && (last_sync_at.nil? || last_sync_at > 4.hours.ago)
  end

  def can_sync?
    active? && api_key.present? && api_url.present?
  end

  # Update metadata
  def update_sync_metadata(data)
    self.metadata = metadata.merge({
      "monthly_usage_cost" => data["monthly_usage_cost"],
      "monthly_limit_cost" => data["monthly_limit_cost"],
      "input_tokens" => data["input_tokens"],
      "output_tokens" => data["output_tokens"],
      "images_generated" => data["images_generated"],
      "last_api_response" => data.except("plan_details")
    })

    self.last_sync_at = Time.current
    self.sync_failures_count = 0
    save!
  end

  def increment_sync_failures!
    increment!(:sync_failures_count)

    # Auto-suspend after too many failures
    if sync_failures_count >= 5
      update!(status: :suspended)
      Rails.logger.warn("Provider #{name} auto-suspended after #{sync_failures_count} sync failures")
    end
  end

  def reset_sync_failures!
    update!(sync_failures_count: 0) if sync_failures_count > 0
  end

  # Get recent usage statistics
  def today_requests
    usage_records.where(timestamp: Date.current.beginning_of_day..Date.current.end_of_day)
                 .sum(:request_count)
  end

  def monthly_requests
    usage_records.where(timestamp: Date.current.beginning_of_month..Date.current.end_of_month)
                 .sum(:request_count)
  end

  def weekly_usage_trend
    # Get last 7 days of usage
    (6.days.ago.to_date..Date.current).map do |date|
      daily_requests = usage_records.where(timestamp: date.beginning_of_day..date.end_of_day)
                                   .sum(:request_count)
      {
        date: date.strftime("%m/%d"),
        requests: daily_requests
      }
    end
  end

  private

  def set_default_api_secret
    self.api_secret = "placeholder" # Required by validation but not used for most providers
  end

  def schedule_initial_sync
    SyncApiUsageJob.perform_later(self.id) if can_sync?
  end

  def default_monthly_limit
    case provider_type&.downcase
    when "anthropic"
      200.0
    when "openai"
      200.0
    when "xai"
      100.0
    else
      100.0
    end
  end
end
