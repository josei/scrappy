require 'digest/md5'
require 'scrappy/extractor/fragment'
require 'scrappy/extractor/formats'
require 'scrappy/extractor/selector'
# Require selectors
Dir["#{File.expand_path(File.dirname(__FILE__))}/selectors/*.rb"].each { |f| require f }

module Scrappy
  module Extractor
    def extract uri, html, kb, referenceable=nil
      synchronize do
        if options.debug
          print "Extracting #{uri}..."; $stdout.flush
        end
        
        # Restart stateful selectors
        kb = RDF::Graph.new(kb.triples)
        
        # Parse document
        content = Nokogiri::HTML(html, nil, 'utf-8')
        
        # Extract each fragment
        options = { :doc => { :uri=>uri, :content=>content }, :referenceable=>referenceable }
        output  = extract_graph(fragments_for(kb, uri), options)

        puts "done!" if self.options.debug

        output.triples
      end
    end
    
    # Returns a list of fragments that have mappings in a given URI
    def fragments_for kb, uri
      root_fragments = kb.find(nil, Node('rdf:type'), Node('sc:Fragment')) - kb.find([], Node('sc:subfragment'), nil)

      selectors = []
      fragments = {}
      root_fragments.each do |fragment|
        fragment.sc::selector.each do |selector|
          fragments[selector] = fragment
          selectors << selector
        end
      end
      
      uri_selectors = selectors.select { |selector| selector.rdf::type.include?(Node('sc:UriSelector')) or
                                                    selector.rdf::type.include?(Node('sc:UriPatternSelector')) }.
                                select { |selector| !kb.node(selector).filter(:uri=>uri).empty? }

      visual_selectors = selectors.select { |selector| selector.rdf::type.include?(Node('sc:VisualSelector')) }

      (uri_selectors + visual_selectors).map { |selector| fragments[selector].proxy }
    end

    # Extracts all mappings from a fragment and returns a graph
    def extract_graph fragments, options
      output = RDF::Graph.new
      fragments.each { |fragment| fragment.extract(options).each { |result| output << result } }
      output
    end
  end
end
