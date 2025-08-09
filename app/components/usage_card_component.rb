# frozen_string_literal: true

class UsageCardComponent < ViewComponent::Base
  def initialize(provider:, plan:, usage:, rate_limit:)
    @provider = provider
    @plan = plan
    @usage = usage
    @rate_limit = rate_limit
  end
end
