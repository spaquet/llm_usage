# app/helpers/application_helper.rb
module ApplicationHelper
  # Navigation helpers
  def nav_link_class(active = false)
    base_classes = "px-4 py-2 rounded-lg text-sm font-medium flex items-center space-x-2 transition-colors"
    if active
      "#{base_classes} bg-blue-100 text-blue-700"
    else
      "#{base_classes} text-gray-600 hover:bg-gray-100 hover:text-gray-900"
    end
  end

  def mobile_nav_link_class(active = false)
    base_classes = "block px-3 py-2 rounded-md text-base font-medium transition-colors"
    if active
      "#{base_classes} bg-blue-100 text-blue-700"
    else
      "#{base_classes} text-gray-600 hover:text-gray-900 hover:bg-gray-100"
    end
  end

  def active_nav_item?(path)
    request.path == path || request.path.start_with?(path + "/")
  end

  # Status and styling helpers
  def status_badge_class(status)
    case status.to_s.downcase
    when "active"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
    when "inactive"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    when "suspended"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
    when "warning", "near_limit"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
    else
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    end
  end

  def progress_bar_color(percentage)
    case percentage
    when 0..50
      "bg-green-600"
    when 51..75
      "bg-yellow-500"
    when 76..90
      "bg-orange-500"
    else
      "bg-red-600"
    end
  end

  # Provider icon helpers
  def provider_icon_class(provider_name)
    case provider_name.to_s.downcase
    when /claude|anthropic/
      "w-10 h-10 bg-orange-100 rounded-lg flex items-center justify-center"
    when /openai|gpt/
      "w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center"
    when /xai|grok/
      "w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center"
    else
      "w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center"
    end
  end

  def provider_icon_color(provider_name)
    case provider_name.to_s.downcase
    when /claude|anthropic/
      "text-orange-600"
    when /openai|gpt/
      "text-green-600"
    when /xai|grok/
      "text-blue-600"
    else
      "text-gray-600"
    end
  end

  # Formatting helpers
  def usage_percentage(used, total)
    return 0 if total.nil? || total.zero?
    ((used.to_f / total.to_f) * 100).round(1)
  end

  def format_number(number)
    return "N/A" if number.nil?

    case number
    when 0..999
      number.to_s
    when 1000..999_999
      "#{(number / 1000.0).round(1)}K"
    when 1_000_000..999_999_999
      "#{(number / 1_000_000.0).round(1)}M"
    else
      "#{(number / 1_000_000_000.0).round(1)}B"
    end
  end

  def format_currency(amount)
    return "$0.00" if amount.nil?
    "$#{sprintf('%.2f', amount)}"
  end

  # Flash message helpers
  def flash_message_class(type)
    base_classes = "border-l-4"
    case type.to_s
    when "notice", "success"
      "#{base_classes} bg-green-50 border-green-400"
    when "alert", "error"
      "#{base_classes} bg-red-50 border-red-400"
    when "warning"
      "#{base_classes} bg-yellow-50 border-yellow-400"
    else
      "#{base_classes} bg-blue-50 border-blue-400"
    end
  end

  # Page title helper
  def page_title(title = nil)
    if title.present?
      content_for(:title, "#{title} | LLM Usage Dashboard")
    else
      "LLM Usage Dashboard"
    end
  end
end
