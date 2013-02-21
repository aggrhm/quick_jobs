namespace :quick_jobs do 
  task :process => :environment do
    Rails.logger = Logger.new(ENV['LOG_FILE'] || STDOUT)
    Rails.logger.info "Starting quick_jobs processor"

    while true do
      Job.waiting.each do |job|
        Rails.logger.info "#{job.summary}"
        job.run
        Rails.logger.info "done"
      end
      sleep 3
    end
  end
end
