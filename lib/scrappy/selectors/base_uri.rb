module BaseUriSelector
  def self.filter selector, doc
    [ { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:uri] } ]
  end
end
