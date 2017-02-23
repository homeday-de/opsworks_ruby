# frozen_string_literal: true

prepare_recipe

every_enabled_application do |application|
  execute 'update whenever schedule' do
    cwd File.join(deploy_dir(application), 'current')
    user 'deploy'
    command 'bundle exec whenever --clear-crontab && bundle exec whenever --write-crontab'
    action :run
  end
end