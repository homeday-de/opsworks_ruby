# frozen_string_literal: true
#
# Cookbook Name:: opsworks_ruby
# Recipe:: configure

prepare_recipe

# setup logrotate for the rails app

file '/etc/logrotate.d/rails_app' do
  content '/srv/www/*/shared/log/*log {
  weekly
  rotate 8
  notifempty
  missingok
  compress
  delaycompress
  copytruncate
}'
  mode '0644'
  owner 'root'
  group 'root'
  action :create_if_missing
end