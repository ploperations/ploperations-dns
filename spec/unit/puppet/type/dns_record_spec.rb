require 'spec_helper'

type_class = Puppet::Type.type(:dns_record)

describe type_class do

  let :params do
    [
      :name,
      :domain,
      :zone_id,
      :username,
      :customername,
      :password,
      :ddns_key,
    ]
  end

  let :properties do
    [
      :content,
      :type,
      :ttl,
    ]
  end

  it 'should have expected properties' do
    properties.each do |property|
      expect(type_class.properties.map(&:name)).to be_include(property)
    end
  end

  it 'should have expected parameters' do
    params.each do |param|
      expect(type_class.parameters).to be_include(param)
    end
  end

  it 'should not have a trailing . in name' do
    #require 'debugger';debugger
    expect( 
      type_class.new({ name: 'trailing.', }).title
    ).to eql('trailing')
  end

  it 'should not fail without a trailing . in name' do
    #require 'debugger';debugger
    expect( 
      type_class.new({ name: 'trailing', }).title
    ).to eql('trailing')
  end

  it 'should require ttl to be a number' do
    expect {
      type_class.new({ name: 'valid', ttl: 'invalid' })
    }.to raise_error(Puppet::Error, /TTL must be an integer/)
  end

end
