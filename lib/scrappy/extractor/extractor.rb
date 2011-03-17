require 'digest/md5'
require 'scrappy/extractor/fragment'
require 'scrappy/extractor/formats'
require 'scrappy/extractor/selector'
# Require selectors
Dir["#{File.expand_path(File.dirname(__FILE__))}/selectors/*.rb"].each { |f| require f }

module Scrappy
  module Extractor
    def extract uri, html, referenceable=nil
      synchronize do
        if options.debug
          print "Extracting #{uri}..."; $stdout.flush
        end
        
        # Restart stateful selectors
        self.kb = RDF::Graph.new(self.kb.triples)
        
        # Parse document
        content = Nokogiri::HTML(html, nil, 'utf-8')
        
        # Extract each fragment
        options = { :doc => { :uri=>uri, :content=>content }, :referenceable=>referenceable }
        triples = []
        fragments_for(uri).each do |fragment|
          kb.node(fragment).extract(options).each do |node|
            triples += node.graph.triples
          end
        end

        # Add references to sources if requested
        triples += add_referenceable_data uri, content, triples, referenceable if referenceable

        puts "done!" if self.options.debug

        triples
      end
    end
    
    def fragments_for uri
      uri_selectors = ( kb.find(nil, Node('rdf:type'), Node('sc:UriSelector')) +
                        kb.find(nil, Node('rdf:type'), Node('sc:UriPatternSelector')) ).
                        flatten.select do |uri_selector|
        !kb.node(uri_selector).filter(:uri=>uri).empty?
      end

      uri_selectors.map { |uri_selector| kb.find(nil, Node('sc:selector'), uri_selector) }.flatten
    end
    
    private
    def add_referenceable_data uri, content, given_triples, referenceable
      triples = []
      resources = {}; given_triples.each { |s,p,o| resources[s] = resources[o] = true }
      
      fragment = Node(Extractor.node_hash(uri, '/'))
      selector = Node(nil)
      presentation = Node(nil)

      selector.rdf::type = Node('sc:UnivocalSelector')
      selector.sc::path = '/'
      selector.sc::document = uri

      fragment.sc::selector = selector

      triples.push(*fragment.graph.merge(presentation.graph).merge(selector.graph).triples) if referenceable==:dump or resources[fragment.id]

      content.search('*').each do |node|
        next if node.text?

        fragment = Extractor.node_hash(uri, node.path)
        
        if referenceable == :dump or resources[fragment]
          selector     = ID(nil)
          presentation = ID(nil)
          
          triples << [selector, ID('rdf:type'), ID('sc:UnivocalSelector')]
          triples << [selector, ID('sc:path'), node.path.to_s]
          triples << [selector, ID('sc:tag'), node.name.to_s]
          triples << [selector, ID('sc:document'), uri]
          
          triples << [presentation, ID('sc:x'), node[:vx].to_s] if node[:vx]
          triples << [presentation, ID('sc:y'), node[:vy].to_s] if node[:vy]
          triples << [presentation, ID('sc:width'), node[:vw].to_s] if node[:vw]
          triples << [presentation, ID('sc:height'), node[:vh].to_s] if node[:vh]
          triples << [presentation, ID('sc:font_size'), node[:vsize].gsub("px","").to_s] if node[:vsize]
          triples << [presentation, ID('sc:font_family'), node[:vfont]] if node[:vfont]
          triples << [presentation, ID('sc:font_weight'), node[:vweight].to_s] if node[:vweight]
          triples << [presentation, ID('sc:text'), node.text.strip]

          triples << [fragment, ID('sc:selector'), selector]
          triples << [fragment, ID('sc:presentation'), presentation]
        end
      end
      triples
    end

    def self.node_hash uri, path
      digest = Digest::MD5.hexdigest("#{uri} #{path}")
      :"_:bnode#{digest}"
    end
  end
end
