# -*- encoding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "omnibus/version"

Gem::Specification.new do |gem|
  gem.name           = "omnibus"
  gem.version        = Omnibus::VERSION
  gem.license        = "Apache 2.0"
  gem.author         = "Chef Software, Inc."
  gem.email          = "releng@getchef.com"
  gem.summary        = "Omnibus is a framework for building self-installing, full-stack software builds."
  gem.description    = gem.summary
  gem.homepage       = "https://github.com/opscode/omnibus"

  gem.required_ruby_version = ">= 2.5"

  gem.files = `git ls-files`.split($/)
  gem.bindir = "bin"
  gem.executables = %w{omnibus}
  gem.test_files = gem.files.grep(/^(test|spec|features)\//)
  gem.require_paths = ["lib"]

  gem.add_dependency "chef-sugar"
  gem.add_dependency "cleanroom"
  gem.add_dependency "mixlib-shellout"
  gem.add_dependency "mixlib-versioning"
  gem.add_dependency "mixlib-cli"
  gem.add_dependency "mixlib-install"
  gem.add_dependency "ohai"
  gem.add_dependency "ruby-progressbar"
  gem.add_dependency "aws-sdk"
  gem.add_dependency "thor"
  gem.add_dependency "ffi-yajl"
  gem.add_dependency "license_scout"
  gem.add_dependency "nio4r"

  gem.add_development_dependency "bundler"
  gem.add_development_dependency "artifactory"
  gem.add_development_dependency "aruba"
  gem.add_development_dependency "chefstyle"
  gem.add_development_dependency "fauxhai"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rspec-json_expectations"
  gem.add_development_dependency "rspec-its"
  gem.add_development_dependency "webmock"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "appbundler"
  gem.add_development_dependency "pry"
end
