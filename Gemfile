source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :test do
  puppetversion = ENV.key?('PUPPET_VERSION') ? "#{ENV['PUPPET_VERSION']}" : ['>= 3.3']
  gem 'puppet', puppetversion
  gem 'puppetlabs_spec_helper'
  gem 'rake'
  gem 'rspec-puppet'
  gem 'metadata-json-lint'
  gem 'beaker'
  gem 'beaker-rspec', :require => false
  gem 'beaker-puppet_install_helper', :require => false
  gem 'net-dns'
  gem 'dnsruby'
end
