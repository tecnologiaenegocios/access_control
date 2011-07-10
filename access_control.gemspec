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
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('rails', '=2.3.5')
  s.add_development_dependency('rspec-rails', '>= 1.3')
  s.add_development_dependency('mysql')
end
