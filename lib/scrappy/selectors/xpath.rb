module XPathSelector
  def self.filter selector, doc
    selector.rdf::value.map do |pattern|
      doc[:content].search(pattern).map do |result|
        if selector.sc::attribute.first
          # Select node's attribute if given
          selector.sc::attribute.map { |attribute| { :uri=>doc[:uri], :content=>result, :value=>result[attribute] } }
        else
          # Select node
          [ { :uri=>doc[:uri], :content=>result, :value=>result.text } ]
        end
      end
    end.flatten
  end
end
