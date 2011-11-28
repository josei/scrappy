module Sc
  class XPathSelector < Selector
    def filter doc
      rdf::value.map do |pattern|
        interval = if sc::index.first
          (sc::index.first.to_i..sc::index.first.to_i)
        else
          (0..-1)
        end
        patterns = sc::keyword
        (doc[:content].search(pattern)[interval] || []).select do |node|
          patterns.any? ? patterns.include?(node.text.clean.downcase) : true
        end.map do |result|
          if sc::attribute.first
            # Select node's attribute if given
            sc::attribute.map { |attribute| { :uri=>doc[:uri], :content=>result, :value=>result[attribute].clean, :attribute=>attribute } }
          else
            # Select node
            [ { :uri=>doc[:uri], :content=>result, :value=>format(result, sc::format, doc[:uri]) } ]
          end
        end
      end.flatten
    end
  end
end