module Sc
  class CssSelector
    include RDF::NodeProxy

    def filter doc
      # By using Nokogiri, CSS and XPath use the same search method
      Sc::XPathSelector.new(node).filter doc
    end
  end
end
