module QuickJobs
  module Job

    STATES = {:waiting => 1, :running => 2, :done => 3, :error => 4}

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

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

          timestamps!

          attr_alias :queue_name, :qn
          attr_alias :instance_class, :cn
          attr_alias :instance_id, :iid
          attr_alias :method_name, :mn
          attr_alias :args, :ars
          attr_alias :state, :st
          attr_alias :opts, :oph
          attr_alias :run_at, :rna

        elsif db == :mongoid
          field :qn, as: :queue_name, type: String
          field :cn, as: :instance_class, type: String
          field :iid, as: :instance_id, type: Moped::BSON::ObjectId
          field :mn, as: :method_name, type: String
          field :ars, as: :args, type: Array
          field :st, as: :state, type: Integer
          field :oph, as: :opts, type: Hash
          field :rna, as: :run_at, type: Time

          mongoid_timestamps!
        end

        enum_methods! :state, STATES

        scope :waiting, lambda{
          where(:st => STATES[:waiting])
        }
        scope :ready, lambda {
          where(:rna => {'$lte' => Time.now})
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
        job.state! :waiting
        job.save
        #puts job.inspect
        return job
      end

      def cancel(job_id)
        job = self.find(job_id)
        job.destroy unless job.nil?
        return job
      end

    end


    def run
      self.state! :running
      self.save
      base = Object.const_get(self.instance_class)
      base = base.find(self.instance_id) unless self.instance_id.nil?
      if base.respond_to? self.method_name.to_sym
        base.send self.method_name.to_sym, *self.args
        self.state! :done
        self.destroy
      else
        self.state! :error
        self.save
      end
    end

    def summary
      "JOB[#{self.queue_name}|#{self.id.to_s}]: #{self.instance_class}:#{self.instance_id.nil? ? 'class' : self.instance_id.to_s} . #{self.method_name} ( #{self.args.join(',')} )"
    end

  end
end
