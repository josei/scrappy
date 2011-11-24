# -*- encoding: utf-8 -*-
module Sc
  class Fragment
    include RDF::NodeProxy
    
    # Extracts data out of a document and returns an array of nodes
    def extract options={}
      all_mappings(options).map { |mapping| mapping[:node] }
    end

    # Returns all mappings of a fragment by
    # recursively processing all submappings.
    def all_mappings options={}
      # Extracts all the mappings and any subfragment
      mappings(options).map do |mapping|
        node         = mapping[:node]
        subfragments = mapping[:subfragments]
        doc          = mapping[:doc]

        # Process subfragments
        consistent = true
        subfragments.each do |subfragment|
          # Get subfragment object
          subfragment = subfragment.proxy Node('sc:Fragment')
          
          # Add triples from submappings
          submappings = subfragment.all_mappings(options.merge(:doc=>doc))

          # Add relations
          submappings.each do |submapping|
            subnode = submapping[:node]
            node.graph << subnode if subnode.is_a?(RDF::Node)
            subfragment.sc::relation.each { |relation| node[relation] += [subnode] }
          end
          
          # Check consistency
          consistent = false if subfragment.sc::min_cardinality.first and submappings.size < subfragment.sc::min_cardinality.first.to_i
          consistent = false if subfragment.sc::max_cardinality.first and submappings.size > subfragment.sc::max_cardinality.first.to_i
        end

        # Skip the node if it has inconsistent relations
        # For example: extracting a sioc:Post with no dc:title would
        # violate the constraint sc:min_cardinality = 1
        next if !consistent
        
        { :node=>node, :subfragments=>subfragments, :doc=>doc }
      end.compact
    end

    # Returns the mappings between this fragment
    # and the RDF nodes it matches
    def mappings options
      # Identify the fragment's mappings
      docs = sc::selector.map { |s| graph.node(s).select options[:doc] }.flatten

      # Generate a result for each page mapping
      docs.map do |doc|
        # Build RDF nodes from identifier selectors (if present)
        node = build_node(doc, options[:referenceable])
        
        # Skip the node if no URI or bnode is created
        next if !node
        
        # Add info to the node

        # Build the object -- it can be a node or a literal
        object = if sc::type.include?(Node('rdf:Literal'))
          value = doc[:value].to_s.gsub("\302\240"," ").strip
          if options[:referenceable]
            node.rdf::value = value
            node.rdf::type += [Node('rdf:Literal')]
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

        # Add referenceable data if requested
        if options[:referenceable] and node.size > 0
          source                = reference(doc)
          source.sc::type       = sc::type
          source.sc::superclass = sc::superclass
          source.sc::sameas     = sc::sameas
          source.sc::relation   = sc::relation
          node.graph           << source
          node.sc::source       = source
        end
        
        # Variable object points to either a node or a literal
        # Return the object, as well as its subfragments (if any)
        # and the doc it was extracted from
        { :node=>object, :subfragments=>sc::subfragment, :doc=>doc }
      end.compact
    end
    
    private
    # Builds a node given a document
    def build_node doc, referenceable
      return Node(nil) if sc::identifier.empty?
      
      sc::identifier.map { |s| graph.node(s).select doc }.flatten.map do |d|
        node = Node(parse_uri(d[:uri], d[:value]))
        
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
        node.rdf::type += [Node("sc:NewUri")] if d[:nofollow]
        
        node
      end.first
    end
    
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