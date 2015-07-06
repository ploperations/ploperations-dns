Puppet.features.add(:rest_client) do
  begin
    require 'rest_client'
  rescue LoadError => e
    warn "Missing gem 'rest-client'. #{e}"
  end
end
