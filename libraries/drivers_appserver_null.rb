# frozen_string_literal: true
module Drivers
  module Appserver
    class Null < Drivers::Appserver::Base
      adapter :null
      allowed_engines :null
      output filter: []

      def after_deploy
      end

      alias after_undeploy after_deploy

      protected

      # rubocop:disable Metrics/AbcSize
      def add_appserver_config
      end
      # rubocop:enable Metrics/AbcSize

      def add_appserver_service_script
      end

      def add_appserver_service_context
      end
    end
  end
end
