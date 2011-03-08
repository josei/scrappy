module Sc
  class RootSelector
    include RDF::NodeProxy
    include Scrappy::Formats

    def filter doc
      if sc::attribute.first
        # Select node's attribute if given
        sc::attribute.map { |attribute| { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:content][attribute] } }
      else
        [ { :uri=>doc[:uri], :content=>doc[:content], :value=>format(doc[:content], sc::format, doc[:uri]) } ]
      end
    end
  end
end