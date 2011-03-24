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
        triples = []
        fragments_for(kb, uri).each do |fragment|
          kb.node(fragment).extract(options).each do |node|
            triples += node.graph.triples
          end
        end

        puts "done!" if self.options.debug

        triples
      end
    end
    
    def fragments_for kb, uri
      all_fragments = kb.find(nil, Node('rdf:type'), Node('sc:Fragment'))
      selectors = []
      fragments = {}
      all_fragments.each do |fragment|
        fragment.sc::selector.each do |selector|
          fragments[selector] = fragment
          selectors << selector
        end
      end
      
      uri_selectors = selectors.select { |selector| selector.rdf::type.include?(Node('sc:UriSelector')) or
                                                    selector.rdf::type.include?(Node('sc:UriPatternSelector')) }.
                                select { |selector| !kb.node(selector).filter(:uri=>uri).empty? }

      visual_selectors = selectors.select { |selector| selector.rdf::type.include?(Node('sc:VisualSelector')) }

      (uri_selectors + visual_selectors).map { |selector| fragments[selector] }
    end
  end
end
