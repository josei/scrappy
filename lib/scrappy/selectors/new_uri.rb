module NewUriSelector
  def self.filter selector, doc
    contents = if selector.sc::attribute.first
      # Select node's attribute if given
      selector.sc::attribute.map { |attribute| doc[:content][attribute] }
    else
      [ doc[:content].text ]
    end

    contents.map do |content|
      new_uri = selector.sc::prefix.first.to_s + content.wikify + selector.sc::suffix.first.to_s
      { :uri=>new_uri, :content=>doc[:content], :value=>new_uri }
    end
  end
end