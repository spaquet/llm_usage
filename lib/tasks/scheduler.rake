# lib/tasks/scheduler.rake
namespace :scheduler do
  desc "Sync API usage data"
  task sync_api_usage: :environment do
    SyncApiUsageJob.perform_later
  end
end
