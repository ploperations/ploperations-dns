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

  def create
    @zone = route53.zones.get(resource[:zone_id])
    @zone.records.all.each do |r|
      if r.name == resource[:name]
        Puppet.debug("Route53: Cannot modify records, must remove #{resource[:name]}.")
        r.destroy
      end
    end

    begin
      Puppet.debug("Attempting to create record type #{resource[:type]} for #{resource[:name]} as #{resource[:content]}")
      record = @zone.records.create( :name  => resource[:name],
                                     :value => resource[:content],
                                     :type  => resource[:type],
                                     :ttl   => resource[:ttl] )
      Puppet.info("Route53: Created #{resource[:type]} record for #{resource[:name]}.#{resource[:domain]}")
    rescue Excon::Errors::UnprocessableEntity
      output = Nokogiri::XML( e.response.body ).xpath( "//xmlns:Message" ).text
      Puppet.info("Route53: #{output}")
    end
  end

  def exists?
    @username, @password = resource[:username], resource[:password]
    resource[:content] = resource[:content].is_a?(Array) ? resource[:content] : resource[:content].to_a
    @zone = route53.zones.get(resource[:zone_id])
    records = @zone.records.all
    if records.detect { |r| r.name == resource[:name] and r.value == resource[:content] and r.ttl == resource[:ttl] }
      return true
    else
      return false
    end
  end

  def destroy
    @zone = route53.zones.get(resource[:zone_id])
    @zone.records.all.each do |r|
      if ( r.name == resource[:name] ) and ( r.type == resource[:type] )
        r.destroy
        Puppet.info("Route53: destroyed #{resource[:type]} record for #{resource[:name]}.#{resource[:domain]}")
      end
    end
  end
end
