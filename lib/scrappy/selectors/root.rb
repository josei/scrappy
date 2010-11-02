module RootSelector
  def self.filter selector, doc
    [ { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:content].text } ]
  end
end
