require 'spec_helper_acceptance'

describe "basic test:" do
  it 'make sure we have installed the module' do
    shell("ls #{default['distmoduledir']}/dns/metadata.json", {:acceptable_exit_codes => 0})
  end
end
