require 'spec_helper'

provider_class = Puppet::Type.type(:dns_record).provider(:bind)

describe provider_class do
  test_records = [
    Puppet::Type.type(:dns_record).new(
      name: 'test-2-a.testme.puppetlabs.net',
      domain: 'testme.puppetlabs.net',
      ttl: 4800,
      type: 'A',
      content: ['172.16.100.100', '172.16.100.200'],
    ),
    Puppet::Type.type(:dns_record).new(
      name: 'test-1-a.testme.puppetlabs.net',
      domain: 'testme.puppetlabs.net',
      ttl: 4800,
      type: 'A',
      content: ['172.16.100.101'],
    ),
    Puppet::Type.type(:dns_record).new(
      name: 'test-cname.testme.puppetlabs.net',
      domain: 'testme.puppetlabs.net',
      ttl: 4800,
      type: 'CNAME',
      content: 'test-1-a.testme.puppetlabs.net',
    ),
    Puppet::Type.type(:dns_record).new(
      name: 'test-txt.testme.puppetlabs.net',
      domain: 'testme.puppetlabs.net',
      ttl: 4800,
      type: 'A',
      content: 'I am a text record',
    ),
  ]
end
