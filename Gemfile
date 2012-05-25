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
  gem 'ruby-debug19'
  gem 'test-unit', '1.2.3'
end

group :guard do
  gem 'guard'
  gem 'guard-rspec'
  gem 'libnotify'
  gem 'rb-inotify'
end

group :mysql do
  gem 'mysql2', "< 0.3.0"
end
