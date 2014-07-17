# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "access_control/version"

Gem::Specification.new do |s|
  s.name        = "access_control"
  s.version     = AccessControl::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["TN"]
  s.email       = ["suporte@tecnologiaenegocios.com.br"]
  s.homepage    = ""
  s.summary     = %q{A gem to help with access control within Rails}
  s.description = %q{A gem to help with access control within Rails}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency('rails', '~> 2.3.5')
  s.add_dependency('backports')
  s.add_dependency('sequel')

  s.add_development_dependency("bundler", "~> 1.6")
  s.add_development_dependency("rake")
  s.add_development_dependency('rspec-rails', '~> 1.3.0')
  s.add_development_dependency('accept_values_for')
  s.add_development_dependency('sqlite3')
end
