Puppet::Type.newtype(:dns_record) do

  @doc = "Manage creation/deletion of DNS records."

  ensurable

  newparam(:name, :namevar => true) do
    desc "The name of the DNS record."

    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end

    # Remove trailing . if present  
    munge do |value|
      if value[-1] == '.'
        value = value.chomp('.')
      else
        value
      end
    end
  end

  newparam(:domain) do
    desc "The domain to add the record to."

    # Remove trailing . if present
    munge do |value|
      if value[-1] == '.'
        value = value.chomp('.')
      else
        value
      end
    end
  end

  newproperty(:content, :array_matching => :all) do
    desc "The content of the DNS record."
  end

  newproperty(:type) do
    desc "The type of DNS record."
  end

  newproperty(:ttl) do
    desc "The TTL of the DNS record. Defaults to 3600."

    munge do |value|
      value.to_i
    end
    validate do |value|
      fail 'TTL must be an integer' unless value.to_i.to_s == value.to_s
    end

    defaultto "3600"
  end

  newparam(:zone_id) do
    desc "The AWS Zone ID. Only needed for Route53."
  end

  newparam(:username) do
    desc "The user name (or AWS key)."
  end

  newparam(:customername) do
    desc "The customer name (needed for DynECT)."
  end

  newparam(:password) do
    desc "The password (or AWS Secret key)."
  end

  newparam(:ddns_key) do
    desc "The file used for bind ddns updates with secret and algorithm."
    validate do |value|
      unless File.exists? value
        raise ArgumentError, "%s does not exists" % value
      end
    end
  end
end
