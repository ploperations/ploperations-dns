Puppet.features.add(:fog) do
  begin
    require 'fog'
  rescue LoadError => e
    warn "Missing gem 'fog'. #{e}"
  end
end
