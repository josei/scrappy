module UriSelector
  def self.filter selector, doc
    # Check if the UriSelector has this URI as value (without params: ?param1=value1&param2=value2)
    if selector.rdf::value.include?(doc[:uri].match(/\A([^\?]*)(\?.*\Z)?/).captures.first)
      [ { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:content].text } ]
    else
      []
    end
  end
end
