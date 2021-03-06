require 'time'

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
        # check if vault token has expired and request a new one if needed
        update_consul_template_config if vault_token_expired?
        consul_template_cmd = <<-TPL
consul-template -config=#{consul_template_config_path} -template "#{template_str}" -retry 30s -once 2>&1
TPL
        app_release_path = release_path
        rails_env = rails_environment
        context.execute 'vault:populate_secrets_yml' do
          puts "EXECUTING VAULT:populate_secrets_yml"
          puts consul_template_cmd
          command "RAILS_ENV=#{rails_env} #{consul_template_cmd}"
          user node['deployer']['user']
          cwd app_release_path
          group www_group
          environment env
          live_stream true
        end
      end

      def configure
        return unless vault_enabled?
        update_consul_template_config
      end

      def update_consul_template_config
        authenticate_to_vault
        create_consul_template_config
      end

      def vault_token_expired?
        vault_token_ff = read_vault_token_from_file
        return true if vault_token_ff.empty?
        
        vault_api_url = vault_attrs.fetch("vault_url")
        curl_cmd =
<<-EOH
curl --header "X-Vault-Token: #{vault_token_ff}" #{vault_api_url}/v1/auth/token/lookup-self | ruby -e 'require "json"; puts JSON.parse(ARGF.read)["data"]["expire_time"]'
EOH
        curl_output = shell_out(curl_cmd)
        expiration_time_utc = Time.iso8601(curl_output.stdout.strip)
        time_now_utc = Time.now.utc
        token_expired = time_now_utc > expiration_time_utc - 20 * 60 # if the token expires within the next 20 minutes, consider it expired
        puts "vault expiration token time #{expiration_time_utc}, time now #{time_now_utc}, token expired : #{token_expired}"
        token_expired
      end

      def validate_app_engine
      end

      def rails_environment
        context.node['deploy'][app_shortname].fetch('global', {}).fetch('environment')
      end

      def vault_enabled?
        context.node['deploy'][app_shortname].fetch('vault', nil)
      end

      protected

      attr_reader :vault_token, :vault_url

      def vault_attrs
        context.node['deploy'][app_shortname]['vault']
      end

      def authenticate_to_vault
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
        # write the vault token to a file too
        File.open(vault_token_file_path, "w") { |f| f.write(@vault_token) }
      end

      def vault_token_file_path
        '/var/chef/.vault-token'
      end

      def read_vault_token_from_file
        IO.read(vault_token_file_path).chomp
      rescue Errno::ENOENT
        nil
      end

      def create_consul_template_config
        vars = {vault_token: @vault_token, vault_url: @vault_url}

        context.template(consul_template_config_path) do
          source 'consul_template_vault.hcl.erb'
          owner node['deployer']['user']
          group www_group
          mode '0644'
          variables vars
          action :create
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
