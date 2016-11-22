module Drivers
  module ConsulTemplate
    class Worker < Drivers::Base
      include Drivers::Dsl::Notifies
      include Drivers::Dsl::Output
      include Chef::Mixin::ShellOut

      attr_accessor :release_path
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
/usr/local/bin/consul-template -config=#{consul_template_config_path} -template "#{template_str}" -retry 30s -once 2>&1
TPL
        app_release_path = release_path

        context.execute 'vault:populate_secrets_yml' do
          # puts "==" * 80
          puts "EXECUTING VAULT:populate_secrets_yml"
          puts consul_template_cmd
          consul_output =`#{consul_template_cmd}`
          puts consul_output
          command "ls"
          user node['deployer']['user']
          cwd app_release_path
          group www_group
          environment env
          live_stream true
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
        curl_cmd = 
<<-EOH
curl -s -XPOST #{vault_url}/v1/auth/app-id/login -d '{"app_id":"#{app_id}", "user_id":"#{user_id}"}' | ruby -e 'require "json"; puts JSON.parse(ARGF.read)["auth"]["client_token"]'
EOH
        curl_output = shell_out(curl_cmd)
        @vault_token = curl_output.stdout.strip.gsub(/\A"|"\Z/, '')        
        context.node.default['deploy'][app_shortname]['vault']['vault_token'] = @vault_token
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
        File.join(release_path, File.join('config', 'secrets.yml.ctmpl'))
      end

      def consul_template_secret_destination_path
        File.join(release_path, File.join('config', 'secrets.yml'))
      end

      def app_shortname
        app['shortname']
      end
    end
  end
end