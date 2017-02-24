# frozen_string_literal: true

prepare_recipe

every_enabled_application do |application|
  execute 'update whenever schedule' do
    cwd File.join(deploy_dir(application), 'current')
    user 'deploy'
    command <<-CMD
/usr/local/bin/bundle show whenever;
if [ $? -eq 0 ]
then
  bundle exec whenever --clear-crontab && bundle exec whenever --write-crontab
else
  echo "whenever not installed, skipping"
fi
    CMD
    action :run
  end
end