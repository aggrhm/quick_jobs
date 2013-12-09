namespace :quick_jobs do 
  task :process => :environment do
    Rails.logger = Logger.new(ENV['LOG_FILE'] || STDOUT)
    if defined?(Moped)
      Moped.logger = nil
    end
    env = ENV['RAILS_ENV'] || 'production'
    Rails.logger.info "Starting quick_jobs processor for #{env}"

    begin
      while Process.ppid != 1 do
        Job.process_ready_jobs(environment: env)
        sleep 3
      end
    rescue Exception => e
      Rails.logger.info "ERROR. Reason:"
      Rails.logger.info e
      Rails.logger.info e.backtrace.join("\n\t")
    end
  end
end
