require "quick_jobs/version"
require "quick_jobs/job"
require "quick_jobs/processable"

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

  end

  module ModelBase

    def report_event(ev, opts={})
      self.handle_event_internally(ev, opts)
      self.handle_event(ev, opts)
    rescue => ex
      if defined?(Rails)
        Rails.logger.info(ex.message)
        Rails.logger.info(ex.backtrace.join("\n\t"))
      end
    end

    def handle_event_internally(ev, opts)
    end

    def handle_event(ev, opts)
      # override this in class
    end

  end

end
