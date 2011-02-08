module CssSelector
  def self.filter selector, doc
    # By using Nokogiri, CSS and XPath use the same search method
    XPathSelector.filter selector, doc
  end
end
