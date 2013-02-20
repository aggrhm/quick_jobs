module QuickJobs
  module Job

    STATES = {:waiting => 1, :running => 2, :done => 3}

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      def quick_jobs_job_keys_for(db)
        key :qn,  String
        key :cn,  String
        key :iid, ObjectId
        key :mn,  String
        key :ars, Array
        key :st,  Integer
        key :oph, Hash

        timestamps!

        attr_alias :queue_name, :qn
        attr_alias :class_name, :cn
        attr_alias :instance_id, :iid
        attr_alias :method_name, :mn
        attr_alias :args, :ars
        attr_alias :state, :st
        attr_alias :opts, :oph

        enum_methods! :state, STATES

        scope :waiting, lambda{
          where(:st => STATES[:waiting])
        }
      end

      # add a job to a queue to be ran by a background runner
      def run_later(queue_name, instance, method_name, args=[], opts={})
        job = self.new
        job.queue_name = queue_name.to_s.strip.downcase
        if instance.class == Class
          job.class_name = instance.to_s
          job.instance_id = nil
        else
          job.class_name = instance.class.to_s
          job.instance_id = instance.id
        end
        job.method_name = method_name.to_s
        job.args = args.is_a?(Array) ? args : [args]
        job.opts = opts
        job.state! :waiting
        job.save
        return job
      end

    end


    def run
      self.state! :running
      self.save
      base = Object.const_get(self.class_name)
      base = base.find(self.instance_id) unless self.instance_id.nil?
      base.send self.method_name.to_sym, *self.args
      self.state! :done
      self.destroy
    end

    def print
      "JOB[#{self.queue_name}|#{self.id.to_s}]: #{self.class_name}:#{self.instance_id.nil? ? 'class' : self.instance_id.to_s} . #{self.method_name} ( #{self.args.join(',')} )"
    end

  end
end
