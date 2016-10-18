
# Author:: Seekingalpha DevOps <devops+puppet@seekingalpha.com>
# Type Name:: dns_record
# Provider:: dynect
#
# Copyright 2016, Seeking Alpha inc.
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

require 'pp'

module Dynect
  module Connection
    def dynect
      @@dns ||= Fog::DNS.new({
        :provider => 'dynect',
        :dynect_customer => @customername,
        :dynect_username => @username,
        :dynect_password => @password
      })
    end
  end
end


Puppet::Type.type(:dns_record).provide(:dynect) do
  desc "Manage DynECT records."

  confine :feature => :fog
  include Dynect::Connection

  mk_resource_methods

  def self.instances(resources = nil)
    if resources
      resources.map do |res|
        new({name:res[:name],
             customername:res[:customername],
             username:res[:username],
             password:res[:password],
             provider:'dynect',
             type:res[:type],
             ttl:res[:ttl],
             content:Array(res[:content]),
             domain:res[:domain],
             ensure:res[:ensure],
             require:res[:require]
        })
      end
    end
  end

  def get_rdata(value)
      case resource[:type]
      # Use strings over symbols because that's what Dynect returns
      # Makes comparison easier
      when "A"
        return {"address" => "#{value}"}
      when "CNAME"
        # Append trailing period if needed
        value << "." if value[-1,1] != "."
        return {"cname" => "#{value}"}
      when "TXT"
        return {"txtdata" => "#{value}"}
      end
  end

  def flush
    @customername, @username, @password = resource[:customername], resource[:username], resource[:password]
    publish_zone = false
    Puppet.debug("Flushing zone #{resource[:domain]}")
    zone = dynect.zones.get(resource[:domain])
    content_dup = resource[:content].dup
    Puppet.debug("content_dup: #{content_dup}")
    case resource[:ensure]
    when :present
      existing = zone.records.all({fqdn:resource[:name]})
      Puppet.debug("EXISTING: #{existing}")

      to_remove, existing = existing.partition do |r|
        (!resource[:content].include?(r.rdata['address'])) && r.type == resource[:type] && r.name == resource[:name]
      end

      Puppet.debug("EXISTING-2: #{existing}")
      Puppet.debug("TO_REMOVE: #{to_remove}")
      to_remove.each do |r|
        Puppet.debug("Removing: #{r.inspect}")
        r.destroy
        publish_zone = true
      end
      existing.each do |r|
        if r.type != resource[:type]
          r.type = resource[:type]
          needs_update = true
        end
        if (! r.ttl.nil?) && r.ttl != resource[:ttl]
          r.ttl = resource[:ttl]
          needs_update = true
        end
        if needs_update
          Puppet.debug("Updating #{r.inspect}")
          r.save
          publish_zone = true
        end
        content_dup -= [r.rdata['address']]
      end
      Puppet.debug("content_dup-2: #{content_dup}")
      if !content_dup.empty?
        content_dup.each do |new_ip|
          zone.records.new(
            name:resource[:name],
            type:resource[:type],
            ttl:resource[:ttl],
            rdata:get_rdata(new_ip)
          ).save
          publish_zone = true
        end
      end
    when :absent
      to_remove = zone.records.all({fqdn:resource[:name]}).select do |r|
        resource[:content].include?(r.rdata['address']) && r.type == resource[:type] && r.name == resource[:name]
      end
      Puppet.debug("Removing: #{resource[:name]}: #{to_remove}")
      to_remove.each do |r|
        r.destroy
        publish_zone = true
      end
    else
      Puppet.error(" Unknow ensure: #{resource[:ensure]}, #{resource}")
      raise "Unknown ensure for dns_record"
    end
    if publish_zone
      Puppet.debug("Publishing zone: #{zone.domain}")
      zone.publish
    end
  end

  def create
    @property_hash[:ensure] = :present
  end

  def exists?
    Puppet.debug("Checking if exists #{resource}")
    @customername, @username, @password = resource[:customername], resource[:username], resource[:password]
    zone = dynect.zones.get(resource[:domain])
    existing = zone.records.all({fqdn:resource[:name]}).select do |r|
      r.type == resource[:type]
    end
    Puppet.debug("EXISTING-3: #{existing}, content: #{resource[:content]}")
    (resource[:content] - existing.map do |r| r.rdata['address'] end).empty?
  end

  def destroy
    @property_hash[:ensure] = :absent
  end
end
