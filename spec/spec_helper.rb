require 'fog'
require 'puppet'

gem 'rspec'

RSpec.configure do |config|
  Fog.mock!
end

