
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

require 'json'

begin
    require "rest_client"
rescue LoadError
    raise Puppet::Error, "Missing gem 'rest-client'"
end

Puppet::Type.type(:dns_record).provide(:dynect) do

  desc "Manage DynECT records."

  def get_token
      url = "https://api.dynect.net/REST/Session/"
      session_data = { :customer_name => resource[:customername], :user_name => resource[:username], :password => resource[:password] }
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

  def set_rdata
      case resource[:type]
      # Use strings over symbols because that's what dynect returns
      # Makes compairison easier
      when "A"
          return {"address" => "#{resource[:content]}"}
      when "CNAME"
          # Append trailing period if needed
          resource[:content] += "." if "#{resource[:content]}"[-1,1] != "."
          return {"cname" => "#{resource[:content]}"}
      when "TXT"
          return {"txtdata" => "#{resource[:content]}"}
      end
  end

  def logout
      url = "https://api2.dynect.net/REST/Session/"
      response = RestClient.delete(url,@headers)
  end

  def create
    begin
      Puppet.debug("Attempting to create record type #{resource[:type]} for #{resource[:name]} as #{resource[:content]}") if @action == "post"
      Puppet.debug("Attempting to edit record type #{resource[:type]} for #{resource[:name]} as #{resource[:content]}") if @action == "put"
      url = "https://api.dynect.net/REST/#{resource[:type]}Record/#{resource[:domain]}/#{resource[:name]}"
      session_data = { :rdata => set_rdata, :ttl => resource[:ttl] }
      response = RestClient.send(@action.to_sym, url,session_data.to_json, @headers)
      obj = JSON.parse(response)
      if obj['status'] == 'success'
          # Publish the zone
          url = "https://api2.dynect.net/REST/Zone/#{resource[:domain]}"
          session_data = { "publish" => "true" }
          response = RestClient.put(url,session_data.to_json,@headers)
          obj = JSON.parse(response)
          if obj['status'] == 'success'
              Puppet.info("DynECT: Created #{resource[:type]} record for #{resource[:name]} with ttl #{resource[:ttl]}") if @action == "post"
              if @old_ttl.nil? and @old_rdata
                  Puppet.info("DynECT: Updated #{resource[:type]} record for #{resource[:name]} from #{@old_rdata.values[0]} to #{resource[:content]}")
              elsif @old_ttl and @old_rdata.nil?
                  Puppet.info("DynECT: Updated #{resource[:type]} record for #{resource[:name]} from ttl #{@old_ttl} to #{resource[:ttl]}")
              else
                  Puppet.info("DynECT: Updated #{resource[:type]} record for #{resource[:name]} from #{@old_rdata.values[0]} to #{resource[:content]} and ttl from #{@old_ttl} to #{resource[:ttl]}") if @action == "put"
              end
              logout
          end
      end
    rescue Excon::Errors::UnprocessableEntity
        Puppet.info("DynECT: #{e.response.body}")
    end
  end

  def exists?
      get_token
      url = "https://api.dynect.net/REST/AllRecord/#{resource[:domain]}/"
      response = RestClient.get(url,@headers)
      obj = JSON.parse(response)
      if obj['status'] != 'success'
          #TODO error handle
      end
      # Find URL that contains the record ID, save it, and request more detailed information from dynect
      index = obj['data'].index{|s| s.include?"#{resource[:type]}Record/#{resource[:domain]}/#{resource[:name]}"}
    if index.nil?
      # Post and put used to determine if updating or creating a record
      @action = "post"
      return false
    end
    @url2 = "https://api.dynect.net#{obj['data'][index]}"
    response2 = RestClient.get(@url2,@headers)
    obj2 = JSON.parse(response2)
    if obj2['data']['fqdn'] == resource[:name] and obj2['data']['ttl'] == resource[:ttl].to_i and obj2['data']['rdata'] == set_rdata
      return true
    else
        # Old data saved for puppet output
        if obj2['data']['fqdn'] == resource[:name] and obj2['data']['ttl'] != resource[:ttl].to_i
            @old_ttl = obj2['data']['ttl']
        end
        if obj2['data']['fqdn'] == resource[:name] and obj2['data']['rdata'] != set_rdata
            @old_rdata = obj2['data']['rdata']
        end
        @action = "put"
        return false
    end
  end

  def destroy
      response = RestClient.delete(@url2,@headers)
      obj = JSON.parse(response)
      if obj['status'] == 'success'
          # Publish the zone
          url = "https://api2.dynect.net/REST/Zone/#{resource[:domain]}"
          session_data = { "publish" => "true" }
          response = RestClient.put(url,session_data.to_json,@headers)
          obj = JSON.parse(response)
          if obj['status'] == 'success'
              Puppet.info("DynECT: destroyed #{resource[:type]} record for #{resource[:name]}")
              logout
          end
      end
  end
end
