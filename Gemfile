source "http://rubygems.org"

# Specify your gem's dependencies in access_control.gemspec
gemspec

gem 'pry'
gem 'pry-doc'

platform :mri_18 do
  gem 'ruby18_source_location'
  gem 'ruby-debug'
  gem 'rcov'
end

platform :mri_19 do
  gem 'pry-stack_explorer', :require => false
  gem 'pry-debugger', :require => false
  gem 'test-unit', '1.2.3'
end

group :guard do
  gem 'guard'
  gem 'guard-rspec'
  gem 'libnotify'
  gem 'rb-inotify'
end

group :mysql do
  platform :mri do
    gem 'mysql2', "< 0.3.0"
  end

  platform :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'jdbc-mysql'
  end
end
