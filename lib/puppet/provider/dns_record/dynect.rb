
# Author:: Charles Dunbar <charles@puppetlabs.com>
# Type Name:: dns_record
# Provider:: dynect
#
# Copyright 2015, Puppet Labs
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


Puppet::Type.type(:dns_record).provide(:dynect) do

  require 'json'

  begin
      require "rest_client"
  rescue LoadError
      raise Puppet::Error, "Missing gem 'rest-client'"
  end

  desc "Manage DynECT records."

  mk_resource_methods


  def self.instances
    # Can't do anything - don't have credentials
  end

  def self.get_token(resources)
    url = "https://api.dynect.net/REST/Session/"
    session_data = { :customer_name => resources.values[0][:customername], :user_name => resources.values[0][:username], :password => resources.values[0][:password] }
    # Going to be reusing headers throughout the provider, has the auth_token
    @headers = { "Content-Type" => 'application/json' }
    response = RestClient.post(url,session_data.to_json,@headers)
    # Parse and read the response, set new header to include auth code
    obj = JSON.parse(response)
    if obj['status'] == 'success'
      auth_token = obj['data']['token']
    else
      raise Puppet::Error, "Unable to authenticate to DynECT - check customer name, username and password are correct"
    end
    # Add Auth-Token to header
    @headers = { "Content-Type" => 'application/json', 'Auth-Token' => auth_token }
  end

  def self.prefetch(resources)
    get_token(resources)
    # Populate array with all resources
    instances = []
    domains = []
    # Get unique list of domains and only grab those zones
    resources.each do |name, resource|
      domains << resource['domain'] unless domains.include?(resource['domain'])
    end
    domains.each do |dom|
      url = "https://api.dynect.net/REST/AllRecord/#{dom}/"
      response = RestClient.get(url,@headers)
      obj = JSON.parse(response)
      if obj['status'] != 'success'
        #TODO error handle for dynect
      end
      instances << obj
    end
    resources.each do |name, resource|
      Puppet.debug("prefetching for #{name}")
      index = nil
      objindex = nil
      instances.each do |obj|
        objindex = instances.index(obj)
        # Find URL that contains the record ID, save it, and request more detailed information from dynect
        index = obj['data'].index{|s| s.include?"#{resource[:type]}Record/#{resource[:domain]}/#{resource[:name]}"}
        break unless index.nil?
      end
      if index.nil?
        # Post and put used to determine if updating or creating a record
        # Post == create, put == update
        result =  { :ensure => :absent}
        result[:headers] = @headers
        result[:ttl] = resource[:ttl]
        result[:content] = resource[:content]
        result[:type] = resource[:type]
        result[:action] = "post"
        resource.provider = new(result)
      else
        @url2 = "https://api.dynect.net#{instances[objindex]['data'][index]}"
        response2 = RestClient.get(@url2,@headers)
        obj2 = JSON.parse(response2)
        if obj2['data']['fqdn'] == resource[:name] and obj2['data']['ttl'] == resource[:ttl].to_i and obj2['data']['rdata'] == set_rdata(resource)
          result =  { :ensure => :present }
          result[:headers] = @headers
          result[:url2] = @url2
          result[:ttl] = resource[:ttl]
          result[:content] = resource[:content]
          result[:type] = resource[:type]
          resource.provider = new(result)
        else
          # Old data saved for puppet output
          if obj2['data']['fqdn'] == resource[:name] and obj2['data']['ttl'] != resource[:ttl].to_i
            @old_ttl = obj2['data']['ttl']
          end
          if obj2['data']['fqdn'] == resource[:name] and obj2['data']['rdata'] != set_rdata(resource)
            @old_rdata = obj2['data']['rdata']
          end
          result =  { :ensure => :present }
          result[:headers] = @headers
          result[:ttl] = obj2['data']['ttl']
          result[:content] = obj2['data']['rdata'].values[0].to_s
          result[:type] = resource[:type]
          result[:old_ttl] = @old_ttl unless @old_ttl.nil?
          result[:old_rdata] = @old_rdata unless @old_rdata.nil?
          result[:action] = "put"
          resource.provider = new(result)
        end
      end
    end
  end

  def flush
    Puppet.debug("flushing zone #{@resource[:domain]}")
    if ! @property_hash.empty? && @property_hash[:ensure] != :absent
      begin
        Puppet.debug("Attempting to create record type #{resource[:type]} for #{resource[:name]} as #{resource[:content][0]}") if @property_hash[:action] == "post"
        Puppet.debug("Attempting to edit record type #{resource[:type]} for #{resource[:name]} as #{resource[:content][0]}") if @property_hash[:action] == "put"
        url = "https://api.dynect.net/REST/#{resource[:type]}Record/#{resource[:domain]}/#{resource[:name]}"
        session_data = { :rdata => self.class.set_rdata(resource), :ttl => resource[:ttl] }
        response = RestClient.send(@property_hash[:action].to_sym, url,session_data.to_json, @property_hash[:headers])
        obj = JSON.parse(response)
        if obj['status'] == 'success'
          # Publish the zone
          url = "https://api2.dynect.net/REST/Zone/#{resource[:domain]}"
          session_data = { "publish" => "true" }
          response = RestClient.put(url,session_data.to_json,@property_hash[:headers])
          obj = JSON.parse(response)
          if obj['status'] == 'success'
            Puppet.info("DynECT: Created #{resource[:type]} record for #{resource[:name]} with ttl #{resource[:ttl]}") if @property_hash[:action] == "post"
            if @property_hash[:old_ttl].nil? and @property_hash[:old_rdata]
              Puppet.info("DynECT: Updated #{resource[:type]} record for #{resource[:name]} from #{@property_hash[:old_rdata].values[0]} to #{resource[:content][0]}")
            elsif @property_hash[:old_ttl] and @property_hash[:old_rdata].nil?
              Puppet.info("DynECT: Updated #{resource[:type]} record for #{resource[:name]} from ttl #{@property_hash[:old_ttl]} to #{resource[:ttl]}")
            else
              Puppet.info("DynECT: Updated #{resource[:type]} record for #{resource[:name]} from #{@property_hash[:old_rdata].values[0]} to #{resource[:content][0]} and ttl from #{@property_hash[:old_ttl]} to #{resource[:ttl]}") if @property_hash[:action] == "put"
            end
          end
        end
      rescue Excon::Errors::UnprocessableEntity
        Puppet.info("DynECT: #{e.response.body}")
      end
    else
      response = RestClient.delete(@property_hash[:url2],@property_hash[:headers])
      obj = JSON.parse(response)
      if obj['status'] == 'success'
        # Publish the zone
        url = "https://api2.dynect.net/REST/Zone/#{resource[:domain]}"
        session_data = { "publish" => "true" }
        response = RestClient.put(url,session_data.to_json,@property_hash[:headers])
        obj = JSON.parse(response)
        if obj['status'] == 'success'
          Puppet.info("DynECT: destroyed #{resource[:type]} record for #{resource[:name]}")
        end
      end
    end
    @property_hash = resource.to_hash
  end

  def self.set_rdata(resource)
      case resource[:type]
      # Use strings over symbols because that's what dynect returns
      # Makes compairison easier
      when "A"
        return {"address" => "#{resource[:content][0]}"}
      when "CNAME"
        # Append trailing period if needed
        resource[:content][0] << "." if resource[:content][0][-1,1] != "."
        return {"cname" => "#{resource[:content][0]}"}
      when "TXT"
        return {"txtdata" => "#{resource[:content][0]}"}
      end
  end

  def self.post_resource_eval()
    begin
      url = "https://api2.dynect.net/REST/Session/"
      response = RestClient.delete(url,@headers)
    rescue => e
      puts "DynECT error logging out - #{e}"
    end
  end

  def create
    @property_hash[:ensure] = :present
  end

  def exists?
    Puppet.debug("Evaluating #{resource[:name]}")
    !(@property_hash[:ensure] == :absent or @property_hash.empty?)
  end

  def destroy
    @property_hash[:ensure] = :absent
  end
end
