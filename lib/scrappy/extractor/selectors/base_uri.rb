module Sc
  class BaseUriSelector < Selector
    def filter doc
      [ { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:uri] } ]
    end
  end
end
