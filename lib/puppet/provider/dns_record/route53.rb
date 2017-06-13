#
# Author:: Jomes Turnbull <james@puppetlabs.com>
# Type Name:: dns_record
# Provider:: route53
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

require 'pp'
require 'nokogiri'

module Route53
  module Connection
    def route53
      @@zone ||= Fog::DNS.new({ :provider => "aws",
                                :aws_access_key_id => @username,
                                :aws_secret_access_key => @password } )
    end
  end
end

Puppet::Type.type(:dns_record).provide(:route53) do

  confine :feature => :fog
  include Route53::Connection

  desc "Manage AWS Route 53 records."

  mk_resource_methods

  def create
    @zone = route53.zones.get(resource[:zone_id])
    Puppet.debug("Comparing all records to #{resource[:name]} #{resource[:type]}")
    @zone.records.all!.each do |r|
      Puppet.debug("Existing record: #{r.name} #{r.type}")
      if r.name.chomp('.') == resource[:name] && r.type == resource[:type]
        Puppet.info("Route53: Cannot modify records, must remove #{resource[:name]}.")
        r.destroy
      end
    end

    begin
      Puppet.debug("Attempting to create record type #{resource[:type]} for #{resource[:name]} as #{resource[:content]}")
      @zone.records.create( :name  => resource[:name],
                                     :value => resource[:content],
                                     :type  => resource[:type],
                                     :ttl   => resource[:ttl] )
      Puppet.info("Route53: Created #{resource[:type]} record for #{resource[:name]}")
    rescue Excon::Errors::UnprocessableEntity
      output = Nokogiri::XML( e.response.body ).xpath( "//xmlns:Message" ).text
      Puppet.info("Route53: #{output}")
    end
  end

  def exists?
    @username, @password = resource[:username], resource[:password]
    resource[:content] = resource[:content].is_a?(Array) ? resource[:content] : resource[:content].to_a
    @zone = route53.zones.get(resource[:zone_id])
    records = @zone.records.all!
    if records.detect { |r| r.name.chomp('.') == resource[:name] and r.value == resource[:content] and r.ttl == resource[:ttl].to_s }
      Puppet.debug("Record #{resource[:name]} #{resource[:type]} with content #{resource[:content]} #{resource[:ttl]} found.")
      return true
    else
      Puppet.debug("Record #{resource[:name]} #{resource[:type]} with content #{resource[:content]} #{resource[:ttl]} not found.")
      return false
    end
  end

  def destroy
    @zone = route53.zones.get(resource[:zone_id])
    @zone.records.all!.each do |r|
      if ( r.name.chomp('.') == resource[:name] ) and ( r.type == resource[:type] )
        Puppet.info("Route53: destroying #{resource[:type]} record for #{resource[:name]}")
        r.destroy
      end
    end
  end
end
