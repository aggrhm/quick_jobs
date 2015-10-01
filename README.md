# QuickJobs

QuickJobs is a library for performing jobs using a background processed queue.
Currently this library only works with MongoDB, but could easily be ported to
another ORM.

## Installation

Add this line to your application's Gemfile:

    gem 'quick_jobs', github: 'agquick/quick_jobs'
    gem 'mongo_helper', github: 'agquick/mongo_helper'

    # optional, or you can use your own daemon manager
    gem 'quick_utils', github: 'agquick/quick_utils'  

And then execute:

    $ bundle install

---

## Usage

This library is built upon the `Job` model. A job stores a method to run when
the job is deemed ready.

### Defining Your Job Model

Define your job model by including the QuickJob::Job module in a new class in
your `app/models` directory.

```ruby
class Job
  include Mongoid::Document
  include QuickJobs::Job

  quick_jobs_job_keys_for(:mongoid)

end
```

That's it, now you are ready to add jobs. If you want to store your jobs in a
separate database than your main application database (recommended), just
specify an alternate database session in your Mongoid configuration file.

### Creating A Job

To run a job, you just specify a method your want to run, and the object you want to run it on.

```ruby
class Upload
  ...

  def receive(opts)
    Job.run_later(:upload, self, :process)
  end

  def process
    # do heavy time-consuming stuff here...
  end

end
```

### Processing Jobs in the Background

The core to processing jobs in the background is to call `Job.process_ready_jobs` in a daemon process. Here's an example of a job runner using the QuickUtils TaskManager.

```ruby
require 'quick_utils'

QuickUtils::TaskManager.run("job_processor") do |config|
  config.root_dir = Dir.pwd
  config.load_rails = true

  config.add_task 3, :seconds do |mgr|
    Job.process_ready_jobs(environment: config[:environment], break_if: lambda { mgr.state != :running })
  end
end
```

This will check for and process any queued jobs every 3 seconds. It is safe to have multiple workers pulling jobs from the same queue.

---

## API

### Job

**Class Methods**

> run_later(queue_name, instance, method_name, args=[], run_at=nil, opts={}) &rarr; job

Queues a new job. Jobs can be ran on classes as well as instances. Use the `run_at` option to delay the job in the queue.

> process_ready_jobs(opts)

Process all jobs queued jobs.

---

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
