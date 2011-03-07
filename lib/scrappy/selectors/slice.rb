module Sc
  class SliceSelector
    include RDF::NodeProxy

    def filter doc
      rdf::value.map do |separator|
        slices = doc[:value].split(separator)
        sc::index.map { |index| slices[index.to_i].to_s.strip }.
                  select { |value| value != "" }.
                  map { |value| { :uri=>doc[:uri], :content=>doc[:content], :value=>value} }
      end.flatten
    end
  end
end