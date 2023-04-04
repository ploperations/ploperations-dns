require 'spec_helper_acceptance'
require 'dnsruby'

describe 'dynect_dns_record' do
  dynect_username   = ENV['DYNECT_USER']
  dynect_customerid = ENV['DYNECT_CUST']
  dynect_password   = ENV['DYNECT_PASS']
  $soa_record       = ENV['DYNECT_SOA'] || 'localhost'

  def find_record(name, type = 'A')
    resolver = Dnsruby::Resolver.new
    resolver.retry_times = 2
    resolver.do_caching = false
    resolver.nameserver = $soa_record
    begin
      a = resolver.query(name.to_s, type)
      a = a.answer[0]
    rescue Dnsruby::NXDomain
      nil
    end
  end

  describe 'should create new records for an existing zone' do
    before(:all) do
      @pp = <<-EOS
        Dns_record {
          username      => '#{dynect_username}',
          customername  => '#{dynect_customerid}',
          password      => '#{dynect_password}',
          provider      => 'dynect'#{' '}
        }
        dns_record { "test-1a-record.puppetware.org":
          ensure  => present,
          domain  => 'puppetware.org',
          content => '172.16.100.150',
          type    => 'A',
          ttl     => '4800',
        }
        dns_record { "test-1b-record.puppetware.org.":
          ensure  => present,
          domain  => 'puppetware.org',
          content => '172.16.100.152',
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
        EOS

      apply_manifest(@pp, catch_failures: true)
      sleep(30)
      @test_1a_record = find_record('test-1a-record.puppetware.org')
      @test_1b_record_trailing = find_record('test-1b-record.puppetware.org.')
      @test_cname_record = find_record('test-cname.puppetware.org', 'CNAME')
      @test_txt_record = find_record('test-txt.puppetware.org', 'TXT')
    end

    it 'runs idempotently' do
      expect(apply_manifest(@pp, catch_failures: true).exit_code).to be_zero
    end

    it 'has the correct names' do
      expect(@test_1a_record.name.to_s).to eq('test-1a-record.puppetware.org')
      expect(@test_cname_record.name.to_s).to eq('test-cname.puppetware.org')
      expect(@test_txt_record.name.to_s).to eq('test-txt.puppetware.org')
    end

    it 'has the correct values' do
      expect(@test_1a_record.rdata.to_s).to eq('172.16.100.150')
      expect(@test_cname_record.rdata.to_s).to eq('test-1a-record.puppetware.org')
      expect(@test_txt_record.rdata[0].to_s).to eq('Test TXT Record')
    end

    it 'has the correct ttls' do
      expect(@test_1a_record.ttl).to eq(4800)
      expect(@test_cname_record.ttl).to eq(16_000)
      expect(@test_txt_record.ttl).to eq(32_000)
    end

    it 'allows for trailing . in names' do
      expect(@test_1b_record_trailing.name.to_s).to eq('test-1b-record.puppetware.org')
    end
  end

  describe 'should be able to edit any fields entry and ttl' do
    before(:each) do
      @pp = <<-EOS
        Dns_record {
        username      => '#{dynect_username}',
        customername  => '#{dynect_customerid}',
        password      => '#{dynect_password}',
        provider      => 'dynect'
        }
        dns_record { "test-1a-record.puppetware.org":
          ensure  => present,
          domain  => 'puppetware.org',
          content => '172.16.100.155',
          type    => 'A',
          ttl     => '48000',
        }
        dns_record { "test-1b-record.puppetware.org.":
          ensure  => present,
          domain  => 'puppetware.org',
          content => '172.16.100.152',
          type    => 'A',
          ttl     => '4800',
        }
        dns_record { "test-cname.puppetware.org":
          ensure  => present,
          domain  => 'puppetware.org',
          content => 'test-1b-record.puppetware.org',
          type    => 'CNAME',
          ttl     => '3600',
        }
        dns_record { "test-txt.puppetware.org":
          ensure  => present,
          domain  => 'puppetware.org',
          content => 'Testing edit TXT Record',
          type    => 'TXT',
          ttl     => '3200',
        }
        EOS

      apply_manifest(@pp, catch_failures: true)
      sleep(30)
      @test_1a_record = find_record('test-1a-record.puppetware.org')
      @test_1b_record_trailing = find_record('test-1b-record.puppetware.org.')
      @test_cname_record = find_record('test-cname.puppetware.org', 'CNAME')
      @test_txt_record = find_record('test-txt.puppetware.org', 'TXT')
    end

    it 'has updated values' do
      expect(@test_1a_record.rdata.to_s).to eq('172.16.100.155')
      expect(@test_cname_record.rdata.to_s).to eq('test-1b-record.puppetware.org')
      expect(@test_txt_record.rdata[0].to_s).to eq('Testing edit TXT Record')
    end
  end

  describe 'should remove entries from dns' do
    before(:each) do
      @pp = <<-EOS
        Dns_record {
        username      => '#{dynect_username}',
        customername  => '#{dynect_customerid}',
        password      => '#{dynect_password}',
        provider      => 'dynect'
        }
        dns_record { "test-1a-record.puppetware.org":
          ensure  => absent,
          domain  => 'puppetware.org',
          content => '172.16.100.155',
          type    => 'A',
          ttl     => '48000',
        }
        dns_record { "test-1b-record.puppetware.org.":
          ensure  => absent,
          domain  => 'puppetware.org',
          content => '172.16.100.152',
          type    => 'A',
          ttl     => '4800',
        }
        dns_record { "test-cname.puppetware.org":
          ensure  => absent,
          domain  => 'puppetware.org',
          content => 'test-1b-record.puppetware.org',
          type    => 'CNAME',
          ttl     => '3600',
        }
        dns_record { "test-txt.puppetware.org":
          ensure  => absent,
          domain  => 'puppetware.org',
          content => 'Testing edit TXT Record',
          type    => 'TXT',
          ttl     => '3200',
        }
        EOS

      apply_manifest(@pp, catch_failures: true)
      sleep(60)
      @test_1a_record = find_record('test-1a-record.puppetware.org')
      @test_1b_record_trailing = find_record('test-1b-record.puppetware.org.')
      @test_cname_record = find_record('test-cname.puppetware.org', 'CNAME')
      @test_txt_record = find_record('test-txt.puppetware.org', 'TXT')
    end

    it 'errors out to show the records dont exist' do
      expect(@test_1a_record).to be_nil
      expect(@test_1b_record_trailing).to be_nil
      expect(@test_cname_record).to be_nil
      expect(@test_txt_record).to be_nil
    end
  end
end
