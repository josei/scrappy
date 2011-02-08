module XPathSelector
  def self.filter selector, doc
    selector.rdf::value.map do |pattern|
      interval = if selector.sc::index.first
        (selector.sc::index.first.to_i..selector.sc::index.first.to_i)
      else
        (0..-1)
      end
      patterns = selector.sc::keyword
      (doc[:content].search(pattern)[interval] || []).select { |node| patterns.any? ? patterns.include?(node.text.downcase.strip) : true }.map do |result|
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