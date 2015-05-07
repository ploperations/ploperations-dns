Puppet::Type.newtype(:dns_record) do

  @doc = "Manage creation/deletion of DNS records."

  ensurable

  newparam(:name, :namevar => true) do
    desc "The name of the DNS record."
  end

  newparam(:domain) do
    desc "The domain to add the record to."
  end

  newproperty(:content, :array_matching => :all) do
    desc "The content of the DNS record."
  end

  newproperty(:type) do
    desc "The type of DNS record."
  end

  newproperty(:ttl) do
    desc "The TTL of the DNS record. Defaults to 3600."

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
end
