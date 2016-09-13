# dns

[![Build Status](https://travis-ci.org/puppetlabs/puppetlabs-dns.png)](https://travis-ci.org/puppetlabs/puppetlabs-dns)
#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with dns](#setup)
    * [Requirements](#Requirements)
    * [Beginning with dns](#beginning-with-dns)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Testing - Running tests](#tests)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)

## Description

This is a DNS record management module with support for creating records in DNSimple, DNSMadeEasy, AWS Route53, DynECT, and bind9.

## Setup

### Requirements

The 'fog' gem is needed to manage all providers except Bind.

For Bind, you'll need to have a key configured for DDNS - https://wiki.debian.org/DDNS has more information

## Usage

Here's an example of the bind9 and dynect provider in use
###Bind9
~~~
# Set default provider/key location

Dns_record {
	provider  => bind,
	ddns_key  => '/etc/bind/keys.d/dhcp_updater',
}

dns_record { "test-2a-records.ops.puppetlabs.net":
  domain  => 'ops.puppetlabs.net',
  content => ['172.16.100.100','172.16.100.201'],
  type    => 'A',
  ttl     => '3200',
  ensure  => present
}
 
dns_record { "test-cname.ops.puppetlabs.net":
  ensure  => present,
  domain  => 'ops.puppetlabs.net',
  content => 'test-1a-record.ops.puppetlabs.net',
  type    => 'CNAME',
  ttl     => '16000',
}
 
dns_record { "test-txt.ops.puppetlabs.net":
  ensure  => present,
  domain  => 'ops.puppetlabs.net',
  content => 'Test TXT Record',
  type    => 'TXT',
  ttl     => '32000',
}
~~~

###DynECT
~~~
# Set defaults for dns_record

Dns_record {
  username      => 'username',
  customername  => 'customername',
  password      => 'password',
  provider      => 'dynect'
}

dns_record { "test-1a-record.puppetware.org":
  ensure  => present,
  domain  => 'puppetware.org',
  content => '172.16.100.150',
  type    => 'A',
  ttl     => '4800',
}

# content can also accept array

dns_record { "test-1a-record.puppetware.org":
  ensure  => present,
  domain  => 'puppetware.org',
  content => ['172.16.100.150', '172.16.100.134'],
  type    => 'A',
  ttl     => '4800',
}

dns_record { "test-cname.puppetware.org":
  ensure  => present,
  domain  => 'puppetware.org',
  content => 'test-1a-record.puppetware.org',
  type    => 'CNAME',
  ttl     => '16000',
}

dns_record { "test-txt.puppetware.org":
  ensure  => present,
  domain  => 'puppetware.org',
  content => 'Test TXT Record',
  type    => 'TXT',
  ttl     => '32000',
}
~~~

## Testing

Right now there's basic unit tests for the dns_record type, and an acceptance test for DynECT for testing creating/editing/deleting records.

To run the unit tests, simply populate the gems with `bundle install` and run the tests with `bundle exec rake spec`.  Add SPEC_OPTS='--format documentation' to the end of that line to get more verbose output.

For the acceptance test, set up a few environment variables to ensure no issues.

* `DYNECT_USER`: The dynect username
* `DYNECT_CUST`: The dynect customer name
* `DYNECT_PASS`: The dynect password
* `DYNECT_SOA`: The SOA of the domain you're testing. In my case it's ns1.p07.dynect.net.  If this isn't set, it will default to localhost for lookups, and may fail tests based on TTL or ttl caches.

## Reference

### Types
* `dns_record`: Used to set up a dns record.

### Parameters
####Type: dns_record
#####`name`
*Required* The name of DNS record.
#####`ttl`
*Optional* The time to live for the record. Accepts an integer.  Defaults to 3600.
#####`type`
*Required* The type of the DNS record.  Accepts A, TXT, and CNAME for dynect, all types for bind9.
#####`content`
*Required* The value of the DNS record. Can accept an array for bind9 and DynECT.


## Limitations

Currently only testing/actively using the DynECT and bind9 portions of this, but am currently keeping the other providers as they should still be working.

The DynECT provider does not currently accept an array for the A record type.  The bind9 provider does.
