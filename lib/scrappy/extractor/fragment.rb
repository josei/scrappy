module Sc
  class Fragment
    include RDF::NodeProxy

    def extract options={}
      uri    = options[:doc][:uri]

      # Identify the fragment's mappings
      docs = sc::selector.map { |s| graph.node(s).select options[:doc] }.flatten

      # Generate nodes for each page mapping
      docs.map do |doc|
        # Build RDF nodes from identifier selectors (if present)
        nodes = self.nodes(uri, doc, options[:referenceable])
        
        # Add info to each node
        nodes.map do |node|
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
            sources = [doc[:content]].flatten.map { |n| Node(Scrappy::Extractor.node_hash(doc[:uri], n.path)) }
            sources.each do |source|
              sc::type.each     { |type|     source.sc::type     += [type] }
              sc::relation.each { |relation| source.sc::relation += [relation] }
              node.graph << source
              node.sc::source += [source]
            end
          end
          
          # Object points to either the node or the literal
          object
        end
      end.flatten.compact
    end
    
    def nodes uri, doc, referenceable
      nodes = sc::identifier.map { |s| graph.node(s).select doc }.flatten.map do |d|
        node = Node(parse_uri(uri, d[:value]))
        
        if referenceable
          # Include the fragment where the URI was built from
          uri_node = Node(nil, node.graph)
          hash     = Scrappy::Extractor.node_hash(d[:uri], d[:content].path)
          
          node.sc::uri        = uri_node
          uri_node.rdf::value = node.to_s
          uri_node.sc::source = Node(hash)
        end
        
        node
      end
      nodes << Node(nil) if nodes.empty?
      
      nodes
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

  end
end