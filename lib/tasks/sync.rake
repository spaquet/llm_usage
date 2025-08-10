# lib/tasks/sync.rake
namespace :sync do
  desc "Sync usage data for all active providers"
  task all: :environment do
    puts "Starting sync for all active providers..."

    providers = Provider.active
    puts "Found #{providers.count} active providers"

    results = { success: 0, failed: 0 }

    providers.find_each do |provider|
      print "Syncing #{provider.name}... "

      begin
        SyncApiUsageJob.perform_now(provider.id)
        puts "✓ Success"
        results[:success] += 1
      rescue => e
        puts "✗ Failed: #{e.message}"
        results[:failed] += 1
      end
    end

    puts "\nSync completed:"
    puts "  Success: #{results[:success]}"
    puts "  Failed: #{results[:failed]}"
  end

  desc "Sync usage data for a specific provider"
  task :provider, [:name] => :environment do |t, args|
    provider_name = args[:name]

    if provider_name.blank?
      puts "Usage: rake sync:provider[provider_name]"
      puts "Available providers:"
      Provider.pluck(:name).each { |name| puts "  - #{name}" }
      exit 1
    end

    provider = Provider.find_by(name: provider_name)

    if provider.nil?
      puts "Provider '#{provider_name}' not found"
      puts "Available providers:"
      Provider.pluck(:name).each { |name| puts "  - #{name}" }
      exit 1
    end

    puts "Syncing #{provider.name}..."

    begin
      SyncApiUsageJob.perform_now(provider.id)
      puts "✓ Sync completed successfully"

      # Show some stats
      puts "\nProvider stats:"
      puts "  Status: #{provider.status}"
      puts "  Last sync: #{provider.last_sync_at || 'Never'}"
      puts "  Monthly usage: $#{provider.monthly_usage_cost}"
      puts "  Monthly limit: $#{provider.monthly_limit_cost}"
      puts "  Usage percentage: #{provider.usage_percentage}%"
      puts "  Today's requests: #{provider.today_requests}"

    rescue => e
      puts "✗ Sync failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "Test connections for all providers"
  task test_connections: :environment do
    puts "Testing connections for all providers..."

    Provider.find_each do |provider|
      print "Testing #{provider.name}... "

      begin
        client = case provider.provider_type&.downcase
                when 'xai'
                  XaiApiClient.new(provider)
                when 'openai'
                  OpenaiApiClient.new(provider)
                when 'anthropic'
                  AnthropicApiClient.new(provider)
                else
                  puts "✗ Unknown provider type: #{provider.provider_type}"
                  next
                end

        if client.test_connection
          puts "✓ Connected"
        else
          puts "✗ Connection failed"
        end

      rescue => e
        puts "✗ Error: #{e.message}"
      end
    end
  end

  desc "Show sync status for all providers"
  task status: :environment do
    puts "Provider Sync Status"
    puts "=" * 50

    Provider.includes(:rate_limits, :usage_records).find_each do |provider|
      puts "\n#{provider.name} (#{provider.provider_type})"
      puts "  Status: #{provider.status}"
      puts "  Last sync: #{provider.last_sync_at || 'Never'}"
      puts "  Sync failures: #{provider.sync_failures_count}"
      puts "  Health: #{provider.healthy? ? '✓ Healthy' : '✗ Unhealthy'}"
      puts "  Monthly usage: $#{provider.monthly_usage_cost} / $#{provider.monthly_limit_cost} (#{provider.usage_percentage}%)"
      puts "  Today's requests: #{provider.today_requests}"

      rate_limit = provider.rate_limits.last
      if rate_limit
        puts "  Rate limit: #{rate_limit.remaining}/#{rate_limit.limit} (resets #{rate_limit.reset_at})"
      else
        puts "  Rate limit: Not available"
      end
    end
  end

  desc "Clean up old usage records (keeps last 90 days)"
  task cleanup: :environment do
    puts "Cleaning up old usage records..."

    cutoff_date = 90.days.ago
    old_records = UsageRecord.where('created_at < ?', cutoff_date)
    count = old_records.count

    if count > 0
      old_records.delete_all
      puts "✓ Deleted #{count} old usage records (older than #{cutoff_date.strftime('%Y-%m-%d')})"
    else
      puts "No old records to clean up"
    end
  end

  desc "Reset sync failures for all providers"
  task reset_failures: :environment do
    puts "Resetting sync failures for all providers..."

    providers_with_failures = Provider.where('sync_failures_count > 0')
    count = providers_with_failures.count

    if count > 0
      providers_with_failures.update_all(sync_failures_count: 0)
      puts "✓ Reset failures for #{count} providers"
    else
      puts "No providers with failures found"
    end
  end

  desc "Suspend providers with too many failures"
  task suspend_failing: :environment do
    puts "Checking for providers with excessive failures..."

    failing_providers = Provider.active.where('sync_failures_count >= 5')

    failing_providers.find_each do |provider|
      provider.update!(status: :suspended)
      puts "⚠️  Suspended #{provider.name} (#{provider.sync_failures_count} failures)"
    end

    if failing_providers.count == 0
      puts "No providers need to be suspended"
    end
  end
end
