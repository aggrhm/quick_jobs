require "quick_jobs/version"
require "quick_jobs/job"

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

  end

end
