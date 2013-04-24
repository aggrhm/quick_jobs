namespace :quick_jobs do 
  task :process => :environment do
    Rails.logger = Logger.new(ENV['LOG_FILE'] || STDOUT)
    Rails.logger.info "Starting quick_jobs processor"
    if defined?(Moped)
      Moped.logger = nil
    end
    env = ENV['RAILS_ENV'] || 'production'

    begin
      while Process.ppid != 1 do
        Job.with_env(env).waiting.ready.each do |job|
          begin
            status = job.set_running!
            next if !status   # skip if can't claim
            Rails.logger.info "#{job.summary}"
            job.run
            Rails.logger.info "done"
          rescue Exception => e
            job.state!(:error)
            job.save
            Rails.logger.info e
            Rails.logger.info e.backtrace.join("\n\t")
          end
        end
        sleep 3
      end
    rescue Exception => e
      Rails.logger.info "ERROR. Reason:"
      Rails.logger.info e
      Rails.logger.info e.backtrace.join("\n\t")
    end
  end
end
