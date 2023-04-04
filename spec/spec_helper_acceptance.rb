require 'beaker-rspec'
require 'beaker/puppet_install_helper'

run_puppet_install_helper

RSpec.configure do |c|
  module_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  c.formatter = :documentation

  c.before :suite do
    hosts.each do |host|
      puppet_module_install(source: module_root, module_name: 'dns')
      if fact_on(host, 'osfamily') == 'Debian'
        install_package(master, 'ruby-dev build-essential libxml++2.6-dev')
      end
      on master, 'gem install rest-client fog --no-ri --no-rdoc'
      on master, 'gem list'
    end
  end
end
