module Sc
  class Fragment
    include RDF::NodeProxy

    def extract_graph options={}
      graph = RDF::Graph.new
      extract(options).each { |node| graph << node }
      graph
    end

    def extract options={}
      uri  = options[:doc][:uri]

      # Identify the fragment's mappings
      docs = sc::selector.map { |s| graph.node(s).select options[:doc] }.flatten

      # Generate nodes for each page mapping
      docs.map do |doc|
        # Build RDF nodes from identifier selectors (if present)
        node = self.build_node(uri, doc, options[:referenceable])
        
        # Skip the node if no URI or bnode is created
        next if !node
        
        # Add info to the node

        # Build the object -- it can be a node or a literal
        object = if sc::type.include?(Node('rdf:Literal'))
          value = doc[:value].to_s.strip
          if options[:referenceable]
            node.rdf::value = value
            node.rdf::type  = Node('rdf:Literal')
            node
          else
            value
          end
        else
          # Add statements about the node
          sc::type.each       { |type|       node.rdf::type += [type] if type != Node('rdf:Resource') }
          sc::superclass.each { |superclass| node.rdfs::subClassOf += [superclass] }
          sc::sameas.each     { |samenode|   node.owl::sameAs += [samenode] }

          node
        end

        # Process subfragments
        consistent = true
        sc::subfragment.each do |subfragment|
          # Get subfragment object
          subfragment = graph.node(subfragment, Node('sc:Fragment'))
          # Extract data from the subfragment
          subnodes    = subfragment.extract(options.merge(:doc=>doc))
          
          # Add relations
          subnodes.each do |subnode|
            node.graph << subnode if subnode.is_a?(RDF::Node)
            subfragment.sc::relation.each { |relation| node[relation] += [subnode] }
          end
          
          # Check consistency
          consistent = false if subfragment.sc::min_cardinality.first and subnodes.size < subfragment.sc::min_cardinality.first.to_i
          consistent = false if subfragment.sc::max_cardinality.first and subnodes.size > subfragment.sc::max_cardinality.first.to_i
        end

        # Skip the node if it has inconsistent relations
        # For example: extracting a sioc:Post with no dc:title would
        # violate the constraint sc:min_cardinality = 1
        next if !consistent
        
        # Add referenceable data if requested
        if options[:referenceable]
          source = reference(doc)
          node.graph << source
          sc::type.each     { |type|     source.sc::type     += [type] }
          sc::relation.each { |relation| source.sc::relation += [relation] }
          node.sc::source += [source]
        end
        
        # Object points to either the node or the literal
        object
      end.compact
    end
    
    def build_node uri, doc, referenceable
      return Node(nil) if sc::identifier.empty?
      
      sc::identifier.map { |s| graph.node(s).select doc }.flatten.map do |d|
        node = Node(parse_uri(uri, d[:value]))
        
        if referenceable
          # Include the fragment where the URI was built from
          uri_node            = Node(nil)
          source              = reference(d)
          uri_node.graph     << source
          uri_node.rdf::value = node.to_s
          uri_node.sc::source = source
          
          node.graph  << uri_node
          node.sc::uri = uri_node
        end
        
        node
      end.first
    end
    
    private
    # Parses a URI by resolving relative paths
    def parse_uri(uri, rel_uri)
      return ID('*') if rel_uri.nil?
      begin
        ID(URI::parse(uri.split('/')[0..3]*'/').merge(rel_uri).to_s)
      rescue
        ID('*')
      end
    end

    # Builds an RDF reference to an HTML node
    def reference doc
      node      = doc[:content].is_a?(Nokogiri::XML::NodeSet) ? doc[:content].first.parent : doc[:content]
      attribute = doc[:attribute]
      uri       = doc[:uri]

      source       = Node(nil)
      selector     = Node(nil)
      presentation = Node(nil)
      
      source.graph       << selector
      source.sc::selector = selector
      
      selector.rdf::type           = Node('sc:UnivocalSelector')
      selector.sc::path            = node.path
      selector.sc::document        = uri
      selector.sc::attribute       = attribute if attribute
      
      if node.path != '/'
        selector.sc::tag        = node.name
        source.graph           << presentation
        source.sc::presentation = presentation
      end
      
      presentation.sc::x           = node[:vx] if node[:vx]
      presentation.sc::y           = node[:vy] if node[:vy]
      presentation.sc::width       = node[:vw] if node[:vw]
      presentation.sc::height      = node[:vh] if node[:vh]
      presentation.sc::font_size   = node[:vsize] if node[:vsize]
      presentation.sc::font_family = node[:vfont] if node[:vfont]
      presentation.sc::font_weight = node[:vweight] if node[:vweight]
      presentation.sc::text        = node.text.strip
      
      source
    end
    
  end
end