#
# Author:: Jomes Turnbull <james@puppetlabs.com>
# Type Name:: dns_record
# Provider:: dnsimple
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

module DNSimple
  module Connection
    def dnsimple
      @@dnsimple ||= Fog::DNS.new(provider: 'DNSimple',
                                   dnsimple_email: @username,
                                   dnsimple_password: @password)
    end
  end
end

Puppet::Type.type(:dns_record).provide(:dnsimple) do
  confine feature: :fog
  include DNSimple::Connection

  desc 'Manage DNSimple records.'

  def create
    @zone = dnsimple.zones.get(resource[:domain])
    @zone.records.all.each do |r|
      if r.name == resource[:name]
        Puppet.debug("DNSimple: Cannot modify records, must remove #{resource[:name]}.")
        r.destroy
      end
    end

    begin
      Puppet.debug("DNSimple: Attempting to create record type #{resource[:type]} for #{resource[:name]} as #{resource[:content]}")
      record = @zone.records.create(name: resource[:name],
                                     value: resource[:content],
                                     type: resource[:type],
                                     ttl: resource[:ttl])
      Puppet.info("DNSimple: Created #{resource[:type]} record for #{resource[:name]}.#{resource[:domain]}")
    rescue Excon::Errors::UnprocessableEntity
      Puppet.debug("DNSimple: #{resource[:name]}.#{resource[:domain]} already exists.")
    end
  end

  def exists?
    @username = resource[:username]
    @password = resource[:password]
    @zone = dnsimple.zones.get(resource[:domain])
    records = @zone.records.all
    if records.detect { |r| (r.name == resource[:name]) && (r.value == resource[:content]) && (r.ttl == resource[:ttl].to_i) }
      true
    else
      false
    end
  end

  def destroy
    @zone = dnsimple.zones.get(resource[:domain])
    @zone.records.all.each do |r|
      if (r.name == resource[:name]) && (r.type == resource[:type])
        r.destroy
        Puppet.info("DNSimple: Deleted #{resource[:type]} record for #{resource[:name]}.#{resource[:domain]}")
      end
    end
  end
end
