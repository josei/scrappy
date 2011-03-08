module Sc
  class SectionSelector
    include RDF::NodeProxy
    include Scrappy::Formats
    
    def filter doc
      rdf::value.map do |pattern|
        doc[:content].search('h1, h2, h3, h4, h5, h6, h7, h8, h9, h10').select { |n| n.parent.name!='script' and n.text.downcase.strip == pattern }.map do |node|
          found = false
          content = node.parent.children[node.parent.children.index(node)+1..-1].select { |n| found ||= (n.name==node.name or n.name=='div'); !found }
          
          [ { :uri=>doc[:uri], :content=>content, :value=>content.map{|t| format(t, sc::format, doc[:uri])}.select{|t| t.to_s.strip!=''}*"\n\n" } ]
        end
      end.flatten
    end
  end
end