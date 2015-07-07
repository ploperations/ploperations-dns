Puppet.features.add(:rest_client) do
  begin
    require 'rest_client'
  rescue LoadError => e
    warn "Gem 'rest-client' needed for DynECT. #{e}"
  end
end
