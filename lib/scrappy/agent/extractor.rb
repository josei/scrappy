require 'digest/md5'

module Scrappy
  module Extractor
    def extract uri, html, referenceable=nil
      if options.debug
        print "Extracting #{uri}..."; $stdout.flush
      end

      @selector_pool = {}
      triples = []
      content = Nokogiri::HTML(html, nil, 'utf-8')

      fragments_for(uri).each do |fragment|
        extract_fragment fragment, :doc=>{:uri=>uri, :content=>content },
                                   :parent=>uri, :triples=>triples, :referenceable=>!referenceable.nil?
      end

      add_referenceable_data uri, content, triples, referenceable if referenceable

      puts "done!" if options.debug
      
      triples.map do |s,p,o|
        [ s.is_a?(RDF::Node) ? s.id : s,
          p.is_a?(RDF::Node) ? p.id : p,
          o.is_a?(RDF::Node) ? o.id : o ]
      end 
    end
    
    def fragments_for uri
      uri_selectors  = (kb.find(nil, Node('rdf:type'), Node('sc:UriSelector')) +
                        kb.find(nil, Node('rdf:type'), Node('sc:UriPatternSelector'))).
                        flatten.select do |uri_selector|
        !selector_pool(uri_selector).filter(:uri=>uri).empty?
      end

      uri_selectors.map { |uri_selector| kb.find(nil, Node('sc:selector'), uri_selector) }.flatten
    end
    
    private
    def extract_fragment fragment, options={}
      node = Node(options[:parent])
      uri = options[:doc][:uri]

      # Select nodes
      docs = fragment.sc::selector.map { |s| filter s, options[:doc] }.flatten

      # Generate triples
      docs.each do |doc|
        # Build URIs if identifier present
        nodes = fragment.sc::identifier.map { |s| filter s, doc }.flatten.map do |d|
          node = Node(parse_uri(uri, d[:value]))
          if options[:referenceable]
            # Include the fragment where the URI was built from
            uri_node = Node(nil)
            options[:triples] << [ node,     Node("sc:uri"),    uri_node ]
            options[:triples] << [ uri_node, Node("rdf:value"), node.to_s ]
            options[:triples] << [ uri_node, Node("sc:source"), Node(node_hash(d[:uri], d[:content].path)) ]
          end
          node
        end
        nodes << Node(nil) if nodes.empty?
        
        nodes.each do |node|
          # When the node is included in a triple, this is marked as true
          referenced = false
          
          # Build the object
          object = if fragment.sc::type.include?(Node('rdf:Literal'))
            value = doc[:value].to_s.strip
            if options[:referenceable]
              bnode = Node(nil)
              bnode.rdf::value = value
              bnode.rdf::type = Node('rdf:Literal')
              options[:triples].push *bnode.triples
              bnode
            else
              value
            end
          else
            fragment.sc::type.each       { |type|       referenced=true; options[:triples] << [node, Node('rdf:type'), type] if type != Node('rdf:Resource') }
            fragment.sc::superclass.each { |superclass| referenced=true; options[:triples] << [node, Node('rdfs:subClassOf'), superclass] }
            fragment.sc::sameas.each     { |samenode|   referenced=true; options[:triples] << [node, Node('owl:sameAs'), samenode] }
            node
          end
          fragment.sc::relation.each     { |relation|   referenced=true; options[:triples] << [options[:parent], relation, object] }
          
          # Add referenceable data if requested
          if options[:referenceable] and referenced
            sources = [doc[:content]].flatten.map { |n| Node(node_hash(doc[:uri], n.path)) }
            sources.each do |source|
              options[:triples] << [ object, Node("sc:source"), source ]
              fragment.sc::type.each { |t| options[:triples] << [ source, Node("sc:type"), t ] }
              fragment.sc::relation.each { |relation| options[:triples] << [ source, Node("sc:relation"), relation ] }
            end
          end

          # Process subfragments
          fragment.sc::subfragment.each { |subfragment| extract_fragment subfragment, options.merge(:doc=>doc, :parent=>object) }
        end
      end
    end

    def filter selector, doc
      if selector.sc::debug.first=="true" and options.debug
        puts '== DEBUG'
        puts '== Selector:'
        puts selector.serialize(:yarf, false)
        puts '== On fragment:'
        puts "URI: #{doc[:uri]}"
        puts "Content: #{doc[:content]}"
        puts "Value: #{doc[:value]}"
      end

      # Process selector
      results = selector_pool(selector).filter doc

      if selector.sc::debug.first=="true" and options.debug
        puts "== No results" if results.empty?
        results.each_with_index do |result, i|
          puts "== Result ##{i}:"
          puts "URI: #{result[:uri]}"
          puts "Content: #{result[:content]}"
          puts "Value: #{result[:value].inspect}"
        end
        puts
      end
      
      # Return results if no nested selectors
      return results if selector.sc::selector.empty?

      # Process nested selectors
      results.map do |result|
        selector.sc::selector.map { |s| filter s, result }
      end.flatten
    end
    
    def parse_uri(uri, rel_uri)
      return ID('*') if rel_uri.nil?
      begin
        ID(URI::parse(uri.split('/')[0..3]*'/').merge(rel_uri).to_s)
      rescue
        ID('*')
      end
    end

    def add_referenceable_data uri, content, triples, referenceable
      resources = {}; triples.each { |s,p,o| resources[s] = resources[o] = true }

      fragment = Node(node_hash(uri, '/'))
      selector = Node(nil)
      presentation = Node(nil)

      selector.rdf::type = Node('sc:UnivocalSelector')
      selector.sc::path = '/'
      selector.sc::document = uri

      fragment.sc::selector = selector

      triples.push(*fragment.graph.merge(presentation.graph).merge(selector.graph).triples) if referenceable==:dump or resources[fragment]

      content.search('*').each do |node|
        next if node.text?

        fragment = Node(node_hash(uri, node.path))

        if referenceable == :dump or resources[fragment]
          selector     = Node(nil)
          presentation = Node(nil)

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
    end

    def node_hash uri, path
      digest = Digest::MD5.hexdigest("#{uri} #{path}")
      :"_:bnode#{digest}"
    end
    
    def selector_pool selector
      @selector_pool ||= {}
      @selector_pool[selector.id] ||= kb.node(selector)
    end
  end
end
