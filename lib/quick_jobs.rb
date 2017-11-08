require "quick_jobs/version"
require "quick_jobs/job"
require "quick_jobs/processable"
require "quick_jobs/metable"

module QuickJobs
  # Your code goes here...

  if defined?(Rails)
    class Railtie < Rails::Railtie
      rake_tasks do
        load 'tasks/quick_jobs.rake'
      end
    end
  end

  class << self

    def without_identity_map(&block)
      if defined?(MongoMapper)
        MongoMapper::Plugins::IdentityMap.without(&block)
      elsif defined?(Mongoid)
        Mongoid::unit_of_work({disable: :all}, &block)
      end
    end

    def options
      @options ||= {test_mode: false}
    end

    def notify_connection(channel, opts={})
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        conn = connection.instance_variable_get(:@connection)
        conn.async_exec("NOTIFY #{channel}")
      end
    end

    def wait_for_notify_then_run(channels, opts={}, &block)
      timeout = opts[:timeout] || 15
      logger = opts[:logger]
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        conn = connection.instance_variable_get(:@connection)
        channels.each do |c|
          conn.async_exec("LISTEN #{c}")
        end
        loop do
          begin
            str = conn.wait_for_notify(timeout)
            block.call({channel: str})
          rescue => ex
            if ex.is_a?(Interrupt)
              logger.info "Wait for notify interrupted, stopping."
              break
            end
            if logger
              logger.info e.message
              logger.info e.backtrace.join("\n\t")
            end
            sleep 1
          end
        end
        conn.async_exec("UNLISTEN *")
      end
    end

  end

end
