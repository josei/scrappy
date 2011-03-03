module Sc
  class UriPatternSelector
    include RDF::NodeProxy

    def filter doc
      # Check if the uri fits the pattern
      if rdf::value.any? { |v| doc[:uri] =~ /\A#{v.gsub('.','\.').gsub('*', '.+')}\Z/ }
        [ { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:content].text } ]
      else
        []
      end
    end
  end
end