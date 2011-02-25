module NewUriSelector
  def self.filter selector, doc
    contents = if selector.sc::attribute.first
      # Select node's attribute if given
      selector.sc::attribute.map { |attribute| doc[:content][attribute] }
    else
      [ doc[:content].text ]
    end

    @@indexes ||= Hash.new(0)
    prefix = selector.sc::prefix.first.to_s
    prefix = (prefix =~ /\Ahttp/ ? URI::parse(doc[:uri]).merge(prefix).to_s : "#{doc[:uri]}#{prefix}")
    suffix = selector.sc::suffix.first.to_s

    contents.map do |content|
      variable = selector.sc::sequence.first.to_s=="true" ? (@@indexes[selector] += 1) : content.wikify
      
      new_uri = "#{prefix}#{variable}#{suffix}"
      
      { :uri=>new_uri, :content=>doc[:content], :value=>new_uri }
    end
  end
end