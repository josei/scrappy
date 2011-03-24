module Sc
  class RootSelector < Selector
    def filter doc
      if sc::attribute.first
        # Select node's attribute if given
        sc::attribute.map { |attribute| { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:content][attribute], :attribute=>attribute } }
      else
        [ { :uri=>doc[:uri], :content=>doc[:content], :value=>format(doc[:value], sc::format, doc[:uri]) } ]
      end
    end
  end
end