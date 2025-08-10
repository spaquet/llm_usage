# config/initializers/solid_queue.rb

Rails.application.configure do
  # Set up job priorities
  config.active_job.queue_priority = {
    default: 5,
    sync: 10,      # Higher priority for sync jobs
    health: 3,     # Lower priority for health checks
    cleanup: 1     # Lowest priority for cleanup
  }

  # Configure queue adapters based on environment
  if Rails.env.production?
    config.active_job.queue_adapter = :solid_queue
    # Production uses separate queue database
    config.solid_queue.connects_to = { database: { writing: :queue } }
  elsif Rails.env.development? && ENV["ENABLE_SOLID_QUEUE"] == "true"
    config.active_job.queue_adapter = :solid_queue
    # Development uses main database - no separate connection needed
  else
    # Use async adapter for development by default (simpler)
    config.active_job.queue_adapter = :async
  end
end

# Set up recurring jobs only in production or when explicitly enabled
if Rails.env.production? || ENV["ENABLE_RECURRING_JOBS"] == "true"
  Rails.application.config.after_initialize do
    # Schedule initial sync for all active providers on startup
    if Provider.table_exists? && ENV["SKIP_INITIAL_SYNC"] != "true"
      Rails.logger.info "Scheduling initial provider sync..."
      SyncApiUsageJob.perform_later
    end
  end
end
