
# Author:: Charles Dunbar <charles@puppetlabs.com>
# Type Name:: dns_record
# Provider:: bind
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


Puppet::Type.type(:dns_record).provide(:bind) do

  desc "Manage BIND records."

  mk_resource_methods

  def self.targets(resources = nil)
    targets = []

    if resources
      resources.each do |name, resource|
        if value = resource[:domain]
          targets << value
        end
      end
    end
    targets.uniq.compact
  end

  def self.instances(resources = nil)
    instances = []
    keys = [:name, :ttl, :class, :type, :content]
    ltargets = targets(resources)
    ltargets.each do | target |
      records = `dig axfr #{target} +nostats`.split("\n")
      # convert dig output into an array of hashes
      records.each do | record |
        next if record[0] == ';' or record == "" # Ignore initial dig comments
        # Turn \t from dig into spaces
        record.gsub! /\t/, ' '
        # Remove double quotes from records
        record.gsub! /\"/,''
        converted_hash = {}
        keys.each_with_index {|k,i|converted_hash[k] = record.split(" ", 5)[i]}
        # Remove trailing .
        converted_hash[:name] = converted_hash[:name].chop!
        converted_hash[:content].chop! if converted_hash[:content][-1,1] == '.'
        converted_hash[:content][0].chop! if converted_hash[:content][0][-1,1] == '.'
        converted_hash[:ensure] = :present
        converted_hash[:old_type] = converted_hash[:type]
        # Convert string content to array
        cont_array = []
        # If already found record (multiple A records) - append to previous instance
        dup_a = instances.index { |record| record[:name] == converted_hash[:name] and record[:type] == 'A' and converted_hash[:type] == 'A' }
        if dup_a.nil?
          converted_hash[:content] = cont_array << converted_hash[:content]
          converted_hash[:old_content] = converted_hash[:content]
        else
          instances[dup_a][:content] << converted_hash[:content]
          next
        end
        instances << converted_hash
      end
    end
    instances
  end

  def self.prefetch(resources)
    instances(resources).each do |prov|
      if resource = resources[prov[:name]]
        resource.provider = new(prov)
      end
    end
  end

  def flush
    Puppet.debug("flushing zone #{resource[:domain]}")
    if ! @property_hash.empty? && @property_hash[:ensure] != :absent
      # Need to quote the content property if it's a TXT record
      # Delete existing record if updating
      if ! @property_hash[:name].nil?
        @property_hash[:old_content].each do | value |
          Puppet.debug("Need to delete old record first to edit. Running - echo 'update delete #{resource[:name]} #{resource[:ttl]} #{@property_hash[:old_type]} #{value}\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}")
          if resource[:type] == 'TXT'
            system 'bash', '-c', "echo 'update delete #{resource[:name]} #{resource[:ttl]} #{@property_hash[:old_type]} \"#{value}\"\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}"
          else
            system 'bash', '-c', "echo 'update delete #{resource[:name]} #{resource[:ttl]} #{@property_hash[:old_type]} #{value}\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}"
          end
        end
      end
      # Create record
      #`/bin/bash -c 'echo -e "update add #{resource[:name]} #{resource[:ttl]} #{resource[:type]} #{resource[:content][0]}\nsend"'  | /usr/bin/nsupdate -v -k /etc/dhcp_updater`
      resource[:content].each do | value |
        Puppet.debug("Running - echo 'update add #{resource[:name]} #{resource[:ttl]} #{resource[:type]} #{value}\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}")
        if resource[:type] == 'TXT'
          system 'bash', '-c', "echo 'update add #{resource[:name]} #{resource[:ttl]} #{resource[:type]} \"#{value}\"\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}"
        else
          system 'bash', '-c', "echo 'update add #{resource[:name]} #{resource[:ttl]} #{resource[:type]} #{value}\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}"
        end
        Puppet.info("BIND: Created #{resource[:type]} record for #{resource[:name]} with ttl #{resource[:ttl]}")
      end
    else
      resource[:content].each do | value |
        Puppet.debug("Running - echo 'update delete #{resource[:name]} #{resource[:ttl]} #{resource[:type]} #{value}\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}")
        if resource[:type] == 'TXT'
          system 'bash', '-c', "echo 'update delete #{resource[:name]} #{resource[:ttl]} #{resource[:type]} \"#{value}\"\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}"
        else
          system 'bash', '-c', "echo 'update delete #{resource[:name]} #{resource[:ttl]} #{resource[:type]} #{value}\nsend\' | /usr/bin/nsupdate -v -k #{resource[:ddns_key]}"
        end
        Puppet.info("BIND: destroyed #{resource[:type]} record for #{resource[:name]}")
      end
    end
    @property_hash = resource.to_hash
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
