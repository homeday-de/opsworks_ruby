# frozen_string_literal: true
module Drivers
  module Framework
    class Rails < Drivers::Framework::Base
      adapter :rails
      allowed_engines :rails
      output filter: [
        :migrate, :migration_command, :deploy_environment, :assets_precompile, :assets_precompilation_command,
        :envs_in_console
      ]
      packages debian: 'zlib1g-dev', rhel: 'zlib-devel'

      def raw_out
        super.merge(deploy_environment: { 'RAILS_ENV' => globals[:environment] })
      end

      def configure
        rdses =
          context.search(:aws_opsworks_rds_db_instance).presence || [Drivers::Db::Factory.build(context, app)]
        rdses.each do |rds|
          database_yml(Drivers::Db::Factory.build(context, app, rds: rds))
        end
      end

      def deploy_after_restart
        setup_rails_console
      end

      private

      def database_yml(db)
        return unless db.applicable_for_configuration?

        database = db.out
        # hackety hack: use hashes in the db.out as separate database configs. remove those from the db
        extra_databases = database.keys.select {|key| database[key].is_a?(Hash) }.each_with_object({}) do |key, databases|
          databases[key] = database.delete(key)
        end
        
        deploy_env = globals[:environment]

        context.template File.join(deploy_dir(app), 'shared', 'config', 'database.yml') do
          source 'database.yml.erb'
          mode '0660'
          owner node['deployer']['user'] || 'root'
          group www_group
          variables(database: database, environment: deploy_env, extra_databases: extra_databases)
        end
      end

      def setup_rails_console
        return unless out[:envs_in_console]
        application_rb_path = File.join(deploy_dir(app), 'current', 'config', 'application.rb')

        return unless File.exist?(application_rb_path)
        env_code = "if(defined?(Rails::Console))\n  " +
                   environment.map { |key, value| "ENV['#{key}'] = #{value.inspect}" }.join("\n  ") +
                   "\nend\n"

        contents = File.read(application_rb_path).sub(/(^(?:module|class).*$)/, "#{env_code}\n\\1")

        File.open(application_rb_path, 'w') { |file| file.write(contents) }
      end

      def environment
        app['environment'].merge(out[:deploy_environment])
      end
    end
  end
end
