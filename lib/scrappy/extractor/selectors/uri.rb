module Sc
  class UriSelector < Selector
    def filter doc
      # Check if the UriSelector has this URI as value (without params: ?param1=value1&param2=value2)
      if rdf::value.include?(doc[:uri].match(/\A([^\?]*)(\?.*\Z)?/).captures.first)
        [ { :uri=>doc[:uri], :content=>doc[:content], :value=>format(doc[:value], sc::format, doc[:uri]) } ]
      else
        []
      end
    end
  end
end
