# frozen_string_literal: true

#
# Cookbook Name:: opsworks_ruby
# Recipe:: setup
#

prepare_recipe

# required by the curb gem
# package 'libcurl3'
# package 'libcurl3-gnutls'
# package 'libcurl4-openssl-dev'

# so that mysql2 gem can compile
# package 'libmysqlclient-dev'
# # install mysql-client so you can use cmdline mysql
# package 'mysql-client'
# # imagemagick
# package 'imagemagick'
# # htop
# package 'htop'
# siege artillery
# package 'libc6-dbg'
# package 'gdb'

# consul
include_recipe 'opsworks_ruby::consul'

#logrotate
include_recipe 'opsworks_ruby::logrotate'

# Monit and cleanup
if node['platform_family'] == 'debian'
  execute 'mkdir -p /etc/monit/conf.d'

  file '/etc/monit/conf.d/00_httpd.monitrc' do
    content "set httpd port 2812 and\n    use address localhost\n    allow localhost"
  end
end

# Ruby and bundler
include_recipe 'deployer'

ruby_pkg_version = node['ruby-ng']['ruby_version'].split('.')[0..1]

if node['platform_family'] == 'debian'
  include_recipe 'ruby-ng::dev'
else
  package "ruby#{ruby_pkg_version.join('')}"
  package "ruby#{ruby_pkg_version.join('')}-devel"
  execute "/usr/sbin/alternatives --set ruby /usr/bin/ruby#{ruby_pkg_version.join('.')}"
end

# update rubygems to the latest version
execute "/usr/bin/gem update --system"
# link to the correct bundler
#execute "update-alternatives --force --install /usr/local/bin/bundle bundle /usr/bin/bundle#{ruby_pkg_version.join('.')} 1"
# since the above had no effect, manually install bundler in the correct location
ruby_pkg_version.push("0")
execute "gem install bundler --version=1.16.1 --install-dir=/usr/lib/ruby/gems/#{ruby_pkg_version.join('.')}"

apt_repository 'apache2' do
  uri 'http://ppa.launchpad.net/ondrej/apache2/ubuntu'
  distribution node['lsb']['codename']
  components %w[main]
  keyserver 'keyserver.ubuntu.com'
  key 'E5267A6C'
  only_if { node['platform'] == 'ubuntu' }
end

bundler2_applicable = Gem::Requirement.new('>= 3.0.0.beta1').satisfied_by?(
  Gem::Version.new(Gem::VERSION)
)
gem_package 'bundler' do
  action :install
  version '~> 1' unless bundler2_applicable
end

if node['platform_family'] == 'debian'
  link '/usr/local/bin/bundle' do
    to '/usr/bin/bundle'
  end
else
  link '/usr/local/bin/bundle' do
    to '/usr/local/bin/bundler'
  end
end

execute 'yum-config-manager --enable epel' if node['platform_family'] == 'rhel'

every_enabled_application do |application|
  databases = []
  every_enabled_rds(self, application) do |rds|
    databases.push(Drivers::Db::Factory.build(self, application, rds: rds))
  end

  scm = Drivers::Scm::Factory.build(self, application)
  framework = Drivers::Framework::Factory.build(self, application, databases: databases)
  appserver = Drivers::Appserver::Factory.build(self, application)
  worker = Drivers::Worker::Factory.build(self, application, databases: databases)
  webserver = Drivers::Webserver::Factory.build(self, application)

  fire_hook(:setup, items: databases + [scm, framework, appserver, worker, webserver])
end
