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

    def redis_client
      @redis_client
    end

    def redis_client=(val)
      @redis_client=val
    end

    def exception_handler
      @exception_handler
    end

    def on_exception(&blk)
      @exception_handler = blk
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
              logger.info ex.message
              logger.info ex.backtrace.join("\n\t")
            end
            sleep 1
          end
        end
        conn.async_exec("UNLISTEN *")
      end
    end

    def notify_model_updated(msg)
      return if msg.nil?
      msg[:action] ||= 'updated'
      msg[:event] = "#{msg[:model]}.#{msg[:action]}"
      r = redis_client
      r.publish('model.updated', msg.to_json)
    rescue => ex
      QuickJobs.log_exception(ex)
    end

    def log_exception(ex)
      return if exception_handler.nil?
      exception_handler.call(ex)
    end

  end

end
