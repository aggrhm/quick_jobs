module QuickJobs

  module Processable

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def processable!
        include QuickJobs::ModelBase
        orm = self.processable_orm
        case orm
        when :active_record
          include QuickJobs::Processable::ActiveRecordExtension
        end
        processable_initialize!
      end

      def processing_options
        @processing_options ||= {
          timeout: 5.minutes,
          lock_limit: 25
        }
      end

      def processable_orm
        return :active_record
      end

    end

    module ActiveRecordExtension

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def processable_initialize!
          if self.respond_to?(:field)
            field :processing_started_at, type: Time
            field :processing_id, type: String

            index [:processing_started_at]
          end
          scope :is_processable, lambda {
            where("processing_started_at is null OR processing_started_at < ?", (Time.now - self.processing_options[:timeout]))
          }
        end

        def process_each!(scope, opts={}, &block)
          popts = self.processing_options
          ids = []
          self.transaction do
            models = is_processable.merge(scope)
            ids = models.limit(popts[:lock_limit]).lock("FOR UPDATE SKIP LOCKED").pluck(:id)
            return if ids.empty?
            self.where(id: ids).update_all(processing_started_at: Time.now, processing_id: opts[:id])
          end
          models = self.find(ids)
          models.each do |m|
            begin
              block.call(m)
            rescue => ex
              Rails.logger.info ex.message
              Rails.logger.info ex.backtrace.join("\n\t")
            ensure
              if m.processing_started_at.present?
                m.update_column(:processing_started_at, nil)
              end
            end
          end
          # prevent repeat for now until can handle process errors
          #self.process_each!(scope, opts, &block)
        end

      end   # END CLASS_METHODS

    end   # END ACTIVE_RECORD

  end   # END PROCESSABLE

end   # END QUICK_JOBS
