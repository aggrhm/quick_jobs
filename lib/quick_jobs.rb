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

end
