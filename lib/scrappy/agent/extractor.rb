module Scrappy
  module Extractor
    def extract uri, html, referenceable=nil
      triples = []
      content = Nokogiri::HTML(html, nil, 'utf-8')
      uri_selectors  = kb.find(nil, Node('rdf:type'), Node('sc:UriSelector')).select{ |n| n.rdf::value.include?(uri.match(/\A([^\?]*)(\?.*\Z)?/).captures.first) }
      uri_selectors += kb.find(nil, Node('rdf:type'), Node('sc:UriPatternSelector')).select{|n| n.rdf::value.any?{|v| /\A#{v.gsub('.','\.').gsub('*', '.+')}\Z/ =~ uri} }

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
            value = doc[:value].strip
            if options[:referenceable]
              bnode = Node(nil)
              bnode.rdf::value = value
              bnode.rdf::type = Node('rdf:Literal')
              bnode
            else
              value
            end
          elsif fragment.sc::type.first
            options[:triples] << [node, Node('rdf:type'), fragment.sc::type.first]
            node
          else
            node
          end
          fragment.sc::relation.each { |relation| options[:triples] << [options[:parent], relation, object] }

          # Add referenceable data if requested
          if options[:referenceable]
            source = Node("_:#{doc[:uri]}|#{doc[:content].path}")
            options[:triples] << [ object, Node("sc:source"), source ]
            fragment.sc::type.each { |t| options[:triples] << [ source, Node("sc:type"), t ] }
            fragment.sc::relation.each { |relation| options[:triples] << [ source, Node("sc:relation"), relation ] }
          end

          # Process subfragments
          fragment.sc::subfragment.each { |subfragment| extract_fragment subfragment, options.merge(:doc=>doc, :parent=>object) }
        end
      end
    end

    def filter selector, doc
      content = doc[:content]
      uri = doc[:uri]
      results = if selector.rdf::type.include?(Node('sc:CssSelector')) or
         selector.rdf::type.include?(Node('sc:XPathSelector'))
        selector.rdf::value.map do |pattern|
          content.search(pattern).map do |result|
            if selector.sc::attribute.first
              # Select node's attribute if given
              selector.sc::attribute.map { |attribute| { :uri=>uri, :content=>result, :value=>result[attribute] } }
            else
              # Select node
              [ { :uri=>uri, :content=>result, :value=>result.text } ]
            end
          end
        end.flatten

      elsif selector.rdf::type.include?(Node('sc:SliceSelector'))
        text = content.text
        selector.rdf::value.map do |separator|
          slices = text.split(separator)
          selector.sc::index.map { |index| { :uri=>uri, :content=>content, :value=>slices[index.to_i].to_s.strip} }
        end.flatten

      elsif selector.rdf::type.include?(Node('sc:BaseUriSelector'))
        [ { :uri=>uri, :content=>content, :value=>uri } ]

      else
        [ { :uri=>uri, :content=>content, :value=>content.text } ]
      end

      # Process nested selectors, if any
      return results if selector.sc::selector.empty?
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

      fragment = Node("_:#{uri}|/")
      selector = Node(nil)
      presentation = Node(nil)

      selector.rdf::type = Node('sc:UnivocalSelector')
      selector.sc::path = '/'
      selector.sc::uri = uri

      fragment.sc::selector = selector

      triples.push(*fragment.graph.merge(presentation.graph).merge(selector.graph).triples) if referenceable==:dump or resources.include?(fragment)

      content.search('*').each do |node|
        fragment = Node("_:#{uri}|#{node.path}")

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

          fragment.sc::selector = selector
          fragment.sc::presentation = presentation unless presentation.empty?

          triples.push(*fragment.graph.merge(presentation.graph).merge(selector.graph).triples)
        end
      end
    end
  end
end
