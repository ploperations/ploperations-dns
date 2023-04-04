Puppet::Type.type(:dns_record).provide(:default) do
  desc 'This is a default provider that does nothing.'

  def create
    false
  end

  def destroy
    false
  end

  def exists?
    raise('This is just the default provider all it does is fail')
  end
end
