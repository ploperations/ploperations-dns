Puppet.features.add(:nokogiri) do
  begin
    require 'nokogiri'
  rescue LoadError => e
    warn "Missing gem 'nokogiri'. #{e}"
  end
end
