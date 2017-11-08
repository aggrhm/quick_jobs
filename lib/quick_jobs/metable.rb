module QuickJobs

  module Metable

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def metable!
        if self.respond_to?(:field)
          field :meta_graph_updated_at, type: Time
          field :meta_updated_at, type: Time
          index [:meta_graph_updated_at]
          index [:meta_updated_at]
        end
        scope :needs_meta_update, lambda {
          where("meta_updated_at IS NULL OR (meta_graph_updated_at > meta_updated_at)")
        }
      end

      def process_meta(opts={})
        self.process_each!(needs_meta_update, id: 'process_meta') do |m|
          m.update_meta
        end
      end

      def meta_graph_updated(scope = nil)
        scope ||= self.all
        scope.update_all(meta_graph_updated_at: Time.now)
        QuickJobs.notify_connection("meta_graph_updated")
      end

    end ## END CLASS METHODS

    def meta_graph_updated_for(*models)
      t = Time.now
      models.each do |model|
        next if model.nil?
        if model.respond_to?(:update_all)
          model.update_all(meta_graph_updated_at: t)
        else
          model.update_attribute(:meta_graph_updated_at, t)
        end
      end
      QuickJobs.notify_connection("meta_graph_updated")
    rescue => ex
      Rails.logger.info "Could not update meta graph."
      Rails.logger.info ex.message
      Rails.logger.info ex.backtrace.join("\n\t")
    end

  end

end
