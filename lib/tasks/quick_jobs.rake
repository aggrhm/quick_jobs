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
        Job.with_env(env).waiting.ready.each do |job|
          begin
            status = job.set_running!
            next if !status   # skip if can't claim
            Rails.logger.info "#{job.summary}"
            job.run
            if job.state? :error
              Rails.logger.info "ERROR: #{job.error}"
            else
              Rails.logger.info "done"
            end
          rescue Exception => e
            job.state! :error
            job.error = e.message
            job.save
            Rails.logger.info "ERROR: #{job.error}"
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
