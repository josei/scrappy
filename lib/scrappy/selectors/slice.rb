module SliceSelector
  def self.filter selector, doc
    selector.rdf::value.map do |separator|
      slices = doc[:value].split(separator)
      selector.sc::index.map { |index| { :uri=>doc[:uri], :content=>doc[:content], :value=>slices[index.to_i].to_s.strip} }
    end.flatten
  end
end
