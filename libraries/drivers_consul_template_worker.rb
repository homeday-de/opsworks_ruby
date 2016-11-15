module Drivers
  module ConsulTemplate
    class Worker < Drivers::Base
      include Drivers::Dsl::Notifies
      include Drivers::Dsl::Output
      include Chef::Mixin::ShellOut

      # def out
      #   handle_output(raw_out)
      # end

      # def raw_out
      #   { app['shortname'] => ""}.symbolize_keys
      # end

      def deploy_before_migrate
        return unless vault_enabled?
        template_str = "#{consul_template_secret_template_path}:#{consul_template_secret_destination_path}"
        consul_template_cmd = <<-TPL
consul-template -config=#{consul_template_config_path} -template "#{template_str}" -once
TPL
        app_deploy_dir = deploy_dir(app)
        context.execute 'vault:populate_secrets_yml' do
          command consul_template_cmd
          user node['deployer']['user']
          cwd File.join(app_deploy_dir, 'current')
          group www_group
          environment env
        end        
      end

      def configure
        return unless vault_enabled?
        authenticate_to_vault
        create_consul_template_config
      end

      def validate_app_engine
      end

      def vault_enabled?
        context.node['deploy'][app_shortname].try(:[], 'vault')
      end

      protected

      attr_reader :vault_token, :vault_url

      def authenticate_to_vault
        vault_attrs = context.node['deploy'][app_shortname]['vault']
        @vault_url = vault_attrs.fetch("vault_url")
        app_id = vault_attrs.fetch('app_id')
        user_id = vault_attrs.fetch('user_id')
        puts '=' * 80
    curl_cmd = 
<<-EOH
curl -s -XPOST #{vault_url}/v1/auth/app-id/login -d '{"app_id":"#{app_id}", "user_id":"#{user_id}"}' | ruby -e 'require "json"; puts JSON.parse(ARGF.read)["auth"]["client_token"]'
EOH
        puts "VAULT URL: #{vault_url}"
        puts "APP ID: #{app_id}"
        puts "USER ID: #{user_id}"
        puts "CURL CMD: #{curl_cmd}"
        curl_output = shell_out(curl_cmd)
        puts "shell curl: #{curl_output.inspect}"
        puts "node deploy: #{node['deploy'].inspect}"
        @vault_token = curl_output.stdout.strip.gsub(/\A"|"\Z/, '')        
        context.node.default['deploy'][app_shortname]['vault']['vault_token'] = @vault_token
        puts "token: #{@vault_token}"
      end

      def create_consul_template_config
        vars = {vault_token: @vault_token, vault_url: @vault_url}

        context.template(consul_template_config_path) do
          source 'consul_template_vault.hcl.erb'
          owner node['deployer']['user']
          group www_group
          mode '0644'
          variables vars
          action :create_if_missing
        end
      end

      def consul_template_config_path
        File.join(deploy_dir(app), File.join('shared', 'config', 'consul_template_vault.hcl'))
      end

      def consul_template_secret_template_path
        File.join(deploy_dir(app), File.join('current', 'config', 'secrets.yml.ctmpl'))
      end

      def consul_template_secret_destination_path
        File.join(deploy_dir(app), File.join('current', 'config', 'secrets.yml'))
      end

      def app_shortname
        app['shortname']
      end
    end
  end
end