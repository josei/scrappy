module RootSelector
  def self.filter selector, doc
    if selector.sc::attribute.first
      # Select node's attribute if given
      selector.sc::attribute.map { |attribute| { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:content][attribute] } }
    else
      [ { :uri=>doc[:uri], :content=>doc[:content], :value=>doc[:content].text } ]
    end
  end
end
