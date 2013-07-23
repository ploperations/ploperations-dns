#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/type/dns_record'

type_class = Puppet::Type.type(:dns_record)

describe type_class do

  puts type_class
  subject { type_class }

  properties = [:ensure]
  properties.each do |property|
    it "should have a #{property} property" do
      subject.attrtype(property).should eq(:property)
    end
  end

  parameters = [:name, :domain, :content, :type, :ttl, :zone_id, :username, :password]
  parameters.each do |parameter|
    it "should have a #{parameter} paramater" do
      subject.attrtype(parameter).should eq(:param)
    end
  end
end
