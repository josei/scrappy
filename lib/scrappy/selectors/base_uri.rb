module Sc
  class BaseUriSelector
    include RDF::NodeProxy

    def filter doc
      [ { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:uri] } ]
    end
  end
end
