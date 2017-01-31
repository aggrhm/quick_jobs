module QuickJobs
  module Job

    STATES = {:waiting => 1, :running => 2, :done => 3, :error => 4}

    def self.included(base)
      base.send :include, QuickJobs::ModelBase
      base.extend ClassMethods
    end

    module ClassMethods

      def quick_jobs_job!(opts={})
        opts[:for] ||= :mongoid
        if opts[:for] == :mongoid
          quick_jobs_job_keys_for(:mongoid)
        end
      end

      def quick_jobs_job_keys_for(db)
        if db == :mongomapper
          key :qn,  String
          key :cn,  String
          key :iid, ObjectId
          key :mn,  String
          key :ars, Array
          key :st,  Integer
          key :oph, Hash
          key :rna, Time
          key :env, String
          key :er,  String

          timestamps!

          attr_alias :queue_name, :qn
          attr_alias :instance_class, :cn
          attr_alias :instance_id, :iid
          attr_alias :method_name, :mn
          attr_alias :args, :ars
          attr_alias :state, :st
          attr_alias :opts, :oph
          attr_alias :run_at, :rna
          attr_alias :error, :er

        elsif db == :mongoid
          include MongoHelper::Model
          field :qn, as: :queue_name, type: String
          field :cn, as: :instance_class, type: String
          field :iid, as: :instance_id
          field :mn, as: :method_name, type: String
          field :ars, as: :args, type: Array
          field :st, as: :state, type: Integer
          field :oph, as: :opts, type: Hash
          field :rna, as: :run_at, type: Time
          field :env, as: :env, type: String
          field :er, as: :error, type: String
          field :bt, as: :backtrace, type: Array
          field :ats, as: :attempts, type: Integer, default: 0

          field :st_at, as: :started_at, type: Time
          field :fn_at, as: :finished_at, type: Time

          mongoid_timestamps!
          index({qn: 1})
        end

        enum_methods! :state, STATES

        scope :waiting, lambda{
          where(:st => STATES[:waiting])
        }
        scope :ready, lambda {
          where(:rna => {'$lte' => Time.now})
        }
        scope :with_env, lambda {|env|
          where(:env => env.to_s.strip.downcase)
        }
        scope :in_queue, lambda {|qn|
          if qn.is_a?(Array)
            where(:qn => {'$in' => qn})
          else
            where(:qn => qn)
          end
        }
        scope :not_in_queue, lambda {|qn|
          qns = qn.is_a?(Array) ? qn : [qn]
          where(:qn => {'$nin' => qns})
        }
        scope :with_error, lambda {
          where(st: STATES[:error])
        }
      end

      # add a job to a queue to be ran by a background runner
      def run_later(queue_name, instance, method_name, args=[], run_at=nil, opts={})
        job = self.new
        job.queue_name = queue_name.to_s.strip.downcase
        if instance.class == Class
          job.instance_class = instance.to_s
          job.instance_id = nil
        else
          job.instance_class = instance.class.to_s
          job.instance_id = instance.id
        end
        job.method_name = method_name.to_s
        job.args = args.is_a?(Array) ? args : [args]
        job.opts = opts
        if run_at.nil?
          job.run_at = Time.now
        else
          job.run_at = run_at
        end
        job.env = Rails.env.to_s.strip.downcase
        job.state! :waiting
        job.attempts = 0
        job.save
        if QuickJobs.options[:test_mode] == true
          job.run
        end
        #puts job.inspect
        return job
      end

      def cancel(job_id)
        job = self.find(job_id)
        job.destroy unless job.nil?
        return job
      end

      def process_ready_jobs(opts={})
        env = opts[:environment]
        bfn = opts[:break_if]
        crit = self.with_env(env).waiting.ready
        if opts[:job_scope]
          crit = opts[:job_scope].call(crit)
        end
        while (true) do
          break if (bfn && bfn.call == true)
          job = crit.find_and_modify({"$set" => {st: STATES[:running]}}, new: true)
          break if job.nil?
          job.run
        end
      end

    end

    ## INSTANCE METHODS
    attr_accessor :recent_exception

    def set_running!
      # check if running
      sum = self.summary
      self.reload
      Rails.logger.info sum
      puts "#{sum}\n#{self.summary}" if sum != self.summary
      return false if self.state? :running
      if defined? MongoMapper
        self.set(:st => STATES[:running])
      elsif defined? Mongoid
        if Mongoid::VERSION[0].to_i >= 4
          self.set(:st => STATES[:running])
        else
          self.set(:st, STATES[:running])
        end
      end
      return true
    end

    def run
      Rails.logger.info "#{self.summary}"
      self.started_at = Time.now
      self.state! :running
      self.report_event 'started'
      base = self.instance_class.constantize
      base = base.find(self.instance_id) unless self.instance_id.nil?
      if base.respond_to? self.method_name.to_sym
        base.send self.method_name.to_sym, *self.args
      else
        error = "Base did not respond to method #{self.method_name.to_sym}."
        error += " (Base is nil)" if base.nil?
        raise error
      end
      self.state! :done
    rescue => e
      self.state! :error
      self.error = e.message
      self.recent_exception = e
      Rails.logger.info "ERROR: #{self.error}"
      Rails.logger.info e.backtrace.join("\n\t")
      self.report_event 'error'
      # queue for retry
      self.state! :waiting
      self.run_at = Time.now + 1.minute
    ensure
      self.attempts += 1
      self.finished_at = Time.now
      self.save
      if self.state?(:done)
        self.report_event 'done'
        self.destroy unless (QuickJobs.options[:test_mode] == true)
      end
    end

    def summary
      "#{Time.now.to_s}: JOB[#{self.env}|#{self.queue_name}|#{self.id.to_s}]: #{self.instance_class}:#{self.instance_id.nil? ? 'class' : self.instance_id.to_s} . #{self.method_name} ( #{self.args.join(',')} )"
    end

    def run_time
      return nil if (self.started_at.nil? || self.finished_at.nil?)
      return (self.finished_at - self.started_at)*1000
    end

    def to_api(opt=:default)
      ret = {}
      ret[:id] = self.id.to_s
      ret[:queue_name] = self.queue_name
      ret[:instance_class] = self.instance_class.to_s
      ret[:instance_id] = self.instance_id.to_s
      ret[:method_name] = self.method_name
      ret[:started_at] = self.started_at.to_i
      ret[:finished_at] = self.finished_at.to_i
      ret[:run_time] = (rt = self.run_time) ? rt.round(2) : nil
      ret[:state] = self.state
      ret[:error] = self.error
      return ret
    end

  end
end
