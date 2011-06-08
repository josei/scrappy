module Sc
  class UriPatternSelector < Selector
    def filter doc
      # Check if the uri fits the pattern
      if rdf::value.any? { |v| doc[:uri] =~ /\A#{v.gsub('.','\.').gsub('*', '.+').gsub('?', '\?')}\Z/ }
        [ { :uri=>doc[:uri], :content=>doc[:content], :value=>format(doc[:value], sc::format, doc[:uri]) } ]
      else
        []
      end
    end
  end
end