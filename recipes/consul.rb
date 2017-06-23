# frozen_string_literal: true
#
# Cookbook Name:: opsworks_ruby
# Recipe:: configure

prepare_recipe

package "unzip"
package "jq"

# Download the latest version of Consul Template using the remote_file
# resource in Chef and trigger an extraction.
remote_file "/tmp/consul-template.zip" do
  source "https://releases.hashicorp.com/consul-template/0.18.5/consul-template_0.18.5_linux_amd64.zip"
  owner "root"
  group "root"
  mode "0755"
  backup false
  action :create_if_missing
  notifies :run, "execute[extract_consul_template]", :immediately
end

# Unzips the binary.
execute "extract_consul_template" do
  command <<-EOH
    unzip /tmp/consul-template.zip
    mv consul-template /usr/local/bin/consul-template
    chmod +x /usr/local/bin/consul-template
  EOH
  action :nothing
end

# Create the configuration directory where the template configurations
# will reside.
# directory "/etc/consul-template.d" do
#   owner "root"
#   group "root"
#   action :create
# end

# Create an upstart script - this could also be systemd or some other
# init system of your preference.
# template "/etc/init/consul-template.conf" do
#   source "upstart-consul-template.conf"
#   owner "root"
#   group "root"
#   mode "0644"
#   # notifies :run, "ruby_block[authenticate_against_vault]", :immediately
# end

# Authenticate against vault with app-id strategy
# and store take the token
# ruby_block "authenticate_against_vault" do
#   block do
#     Chef::Resource::RubyBlock.send(:include,Chef::Mixin::ShellOut)

#     vault_attrs = node["deploy"]["vault"] || {}
#     vault_url = vault_attrs.fetch("vault_url")
#     app_id = vault_attrs.fetch("app_id")
#     user_id = vault_attrs.fetch("user_id")
#     puts "=" * 80
#     curl_cmd = 
# <<-EOH
# curl -s -XPOST #{vault_url}/v1/auth/app-id/login -d '{"app_id":"#{app_id}", "user_id":"#{user_id}"}' |jq '.["auth"]["client_token"]'
# EOH
#     puts "VAULT URL: #{vault_url}"
#     puts "APP ID: #{app_id}"
#     puts "USER ID: #{user_id}"
#     puts "CURL CMD: #{curl_cmd}"
#     curl_output = shell_out(curl_cmd)
#     puts "shell curl: #{curl_output.inspect}"
#     puts "node deploy: #{node['deploy'].inspect}"
#     node.default["deploy"]["vault"]["vault_token"] = curl_output.stdout.strip.gsub(/\A"|"\Z/, "")
#   end
#   action :run
# end

    
# write the vault config into the /etc/consul-template.d/
# template "/etc/consul-template.d/vault.hcl" do
#   source "vault.hcl.erb"
#   owner "root"
#   group "root"
#   mode "0644"
#   variables(node: node)
#   notifies :reload, "service[consul-template]", :immediately
# end

# Start the service and register it with Chef.
# service "consul-template" do
#   provider Chef::Provider::Service::Upstart
#   action [:enable, :start]
# end

# This writes the Consul Template template that Consul Template will
# read, parse, communicate with Vault, and render as the application
# configuration. Since Consul Template is running as a process, it
# will read all files in /etc/consul-template.d as configured in the
# upstart script above.
# template "/etc/consul-template.d/my-app.hcl" do
#   source "my-app-ct.hcl"
#   owner "root"
#   group "root"
#   mode "0644"
#   notifies :reload, "service[consul-template]", :delayed
# end