require 'digest/md5'

module Scrappy
  module Extractor
    def extract uri, html, referenceable=nil
      triples = []
      content = Nokogiri::HTML(html, nil, 'utf-8')

      uri_selectors  = kb.find(nil, Node('rdf:type'), Node('sc:UriSelector')) + kb.find(nil, Node('rdf:type'), Node('sc:UriPatternSelector')).flatten.select do |uri_selector|
        class_name = uri_selector.rdf::type.first.to_s.split('#').last
        results = Kernel.const_get(class_name).filter uri_selector, {:content=>content, :uri=>uri}
        !results.empty?
      end

      fragments = uri_selectors.map { |uri_selector| kb.find(nil, Node('sc:selector'), uri_selector) }.flatten

      fragments.each do |fragment|
        extract_fragment fragment, :doc=>{:uri=>uri, :content=>content },
                                   :parent=>uri, :triples=>triples, :referenceable=>!referenceable.nil?
      end

      add_referenceable_data content, triples, referenceable if referenceable

      triples
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
        nodes = fragment.sc::identifier.map { |s| filter s, doc }.flatten.map{ |d| Node(parse_uri(uri, d[:value])) }
        nodes << Node(nil) if nodes.empty?

        nodes.each do |node|
          # Build the object
          object = if fragment.sc::type.first == Node('rdf:Literal')
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
            if fragment.sc::type.first and fragment.sc::type.first != Node('rdf:Resource')
              options[:triples] << [node, Node('rdf:type'), fragment.sc::type.first]
            end
            fragment.sc::superclass.each { |superclass| options[:triples] << [node, Node('rdfs:subClassOf'), superclass] }
            fragment.sc::sameas.each { |samenode| options[:triples] << [node, Node('owl:sameAs'), samenode] }
            node
          end
          fragment.sc::relation.each { |relation| options[:triples] << [options[:parent], relation, object] }

          # Add referenceable data if requested
          if options[:referenceable]
            sources = [doc[:content]].flatten.map { |node| Node(node_hash(doc[:uri], node.path)) }
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
      # From "BaseUriSelector" to "base_uri"
      class_name = selector.rdf::type.first.to_s.split('#').last

      if !selector.sc::debug.empty?
        puts '== DEBUG'
        puts '== Selector:'
        puts selector.serialize(:yarf, false)
        puts '== On fragment:'
        puts "URI: #{doc[:uri]}"
        puts "Content: #{doc[:content]}"
        puts "Value: #{doc[:value]}"
      end

      # Process selector
      results = Kernel.const_get(class_name).filter selector, doc

      if !selector.sc::debug.empty?
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
        ID(URI::parse(uri.split('/')[0..3]*'/').merge(rel_uri))
      rescue
        ID('*')
      end
    end

    def add_referenceable_data content, triples, referenceable
      resources = triples.map{|s,p,o| [[s],[o]]}.flatten

      fragment = Node(node_hash(uri, '/'))
      selector = Node(nil)
      presentation = Node(nil)

      selector.rdf::type = Node('sc:UnivocalSelector')
      selector.sc::path = '/'
      selector.sc::children = content.search('*').size.to_s
      selector.sc::uri = uri

      fragment.sc::selector = selector

      triples.push(*fragment.graph.merge(presentation.graph).merge(selector.graph).triples) if referenceable==:dump or resources.include?(fragment)

      content.search('*').each do |node|
        fragment = Node(node_hash(uri, node.path))

        if referenceable == :dump or resources.include?(fragment)
          selector = Node(nil)
          presentation = Node(nil)

          selector.rdf::type = Node('sc:UnivocalSelector')
          selector.sc::path = node.path.to_s
          selector.sc::tag = node.name.to_s
          selector.sc::uri = uri

          presentation.sc::x = node[:vx].to_s if node[:vx]
          presentation.sc::y = node[:vy].to_s if node[:vy]
          presentation.sc::width = node[:vw].to_s if node[:vw]
          presentation.sc::height = node[:vh].to_s if node[:vh]
          presentation.sc::font_size = node[:vsize].gsub("px","").to_s if node[:vsize]
          presentation.sc::font_weight = node[:vweight].to_s if node[:vweight]
          presentation.sc::color = node[:vcolor].to_s if node[:vcolor]
          presentation.sc::background_color = node[:vbcolor].to_s if node[:vbcolor]
          presentation.sc::text = node.text.strip
          presentation.sc::children_count = node.search('*').size.to_s

          fragment.sc::selector = selector
          fragment.sc::presentation = presentation unless presentation.empty?

          triples.push(*fragment.graph.merge(presentation.graph).merge(selector.graph).triples)
        end
      end
    end

    def node_hash uri, path
      digest = Digest::MD5.hexdigest("#{uri} #{path}")
      "_:bnode#{digest}"
    end
  end
end
