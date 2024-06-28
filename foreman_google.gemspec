require File.expand_path('lib/foreman_google/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'foreman_google'
  s.version     = ForemanGoogle::VERSION
  s.metadata    = { 'is_foreman_plugin' => 'true',
'rubygems_mfa_required' => 'true' }
  s.license     = 'GPL-3.0'
  s.authors     = ['The Foreman Team']
  s.email       = ['dev@community.theforeman.org']
  s.homepage    = 'https://github.com/theforeman/foreman_google'
  s.summary     = 'Google Compute Engine plugin for the Foreman'
  s.description = 'Google Compute Engine plugin for the Foreman'
  s.required_ruby_version = '>= 2.7', '< 4'

  s.files = Dir['{app,config,db,lib,locale,webpack}/**/*'] + ['LICENSE', 'Rakefile', 'README.md', 'package.json']
  s.test_files = Dir['test/**/*'] + Dir['webpack/**/__tests__/*.js']

  s.add_dependency 'google-apis-compute_v1', '~> 0.14'
  s.add_dependency 'google-cloud-compute', '~> 0.2'
  s.add_development_dependency 'rdoc'
end
