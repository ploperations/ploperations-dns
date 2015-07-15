#
# Author:: Jomes Turnbull <james@puppetlabs.com>
# Type Name:: dns_record
# Provider:: dnsmadeeasy
#
# Copyright 2011, Puppet Labs
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module DNSMadeeasy
  module Connection
    def dnsmadeeasy
      @@dnsmadeeasy ||= Fog::DNS.new( :provider               => "DNSMadeEasy",
                                      :dnsmadeeasy_api_key    => @username,
                                      :dnsmadeeasy_secret_key => @password )
    end
  end
end

Puppet::Type.type(:dns_record).provide(:dnsmadeeasy) do

  confine :feature => :fog
  include DNSMadeeasy::Connection

  desc "Manage DNSMadeEasy records."

  def create
    @zone = dnsmadeeasy.zones.get(resource[:domain])
    @zone.records.all.each do |r|
      if r.name == resource[:name]
        Puppet.debug("DNSMadeEasy: Cannot modify records, must remove #{resource[:name]}.")
        r.destroy
      end
    end

    begin
      Puppet.debug("DNSMadeEasy: Attempting to create record type #{resource[:type]} for #{resource[:name]} as #{resource[:content]}")
      record = @zone.records.create( :name  => resource[:name],
                                     :value => resource[:content],
                                     :type  => resource[:type],
                                     :ttl   => resource[:ttl] )
      Puppet.info("DNSMadeEasy: Created #{resource[:type]} record for #{resource[:name]}.#{resource[:domain]}")
    rescue Excon::Errors::UnprocessableEntity
      Puppet.debug("DNSMadeEasy: #{resource[:name]}.#{resource[:domain]} already exists.")
    end
  end

  def exists?
    @username, @password = resource[:username], resource[:password]
    @zone = dnsmadeeasy.zones.get(resource[:domain])
    records = @zone.records.all
    if records.detect { |r| r.name == resource[:name] and r.value == resource[:content] and r.ttl == resource[:ttl].to_i }
      return true
    else
      return false
    end
  end

  def destroy
    @zone = dnsmadeeasy.zones.get(resource[:domain])
    @zone.records.all.each do |r|
      if ( r.name == resource[:name] ) and ( r.type == resource[:type] )
        r.destroy
        Puppet.info("DNSMadeEasy: Deleted #{resource[:type]} record for #{resource[:name]}.#{resource[:domain]}")
      end
    end
  end
end
