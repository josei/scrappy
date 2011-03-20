module Scrappy
  module Trainer
    # Generates visual patterns
    def train *samples
      RDF::Graph.new( samples.inject([]) do |triples, sample|
        triples + train_sample(sample).triples
      end )
    end
    
    private
    def train_sample sample
      results = RDF::Graph.new extract(sample[:uri], sample[:html], Scrappy::Kb.extractors, :minimum)

      typed_nodes     = results.find(nil, Node("rdf:type"), [])
      non_root_nodes  = results.find([], [], nil)

      nodes = typed_nodes - non_root_nodes
      
      RDF::Graph.new( nodes.inject([]) do |triples, node|
        triples + fragment_for(node).graph.triples
      end )
    end
    
    def fragment_for node, parent=nil
      fragment = Node(nil)
      node.keys.each do |predicate|
        case predicate
        when ID("sc:source") then
          selector = selector_for(node.sc::source.first, parent)
          fragment.graph << selector
          fragment.sc::selector = selector
        when ID("sc:uri") then
          # Assumption: URIs are extracted from a link
          selector = selector_for(node.sc::uri.first.sc::source.first, node)
          selector.sc::tag = "a"
          selector.sc::attribute = "href"

          fragment.graph << selector
          fragment.sc::identifier = selector
        when ID("rdf:type") then
          fragment.sc::type = node.rdf::type
        else
          if node[predicate].map(&:class).uniq.first != String
            node[predicate].map do |subnode|
              subfragment = fragment_for(subnode, node)
              subfragment.sc::relation = Node(predicate)
              subfragment.sc::min_cardinality = "1"
          
              fragment.graph << subfragment
              fragment.sc::subfragment += [subfragment]
            end
          end
        end
      end
      fragment.rdf::type = Node("sc:Fragment") if parent.nil?
      fragment
    end
    
    def selector_for fragment, parent=nil
      presentation = fragment.sc::presentation.first
      
      selector = Node(nil)
      selector.rdf::type = Node("sc:VisualSelector")

      origin_x = parent ? parent.sc::source.first.sc::presentation.first.sc::x.first.to_i : 0
      origin_y = parent ? parent.sc::source.first.sc::presentation.first.sc::y.first.to_i : 0
      
      relative_x = presentation.sc::x.first.to_i - origin_x
      relative_y = presentation.sc::y.first.to_i - origin_y
      
      selector.sc::min_relative_x  = relative_x.to_s
      selector.sc::max_relative_x  = relative_x.to_s
      selector.sc::min_relative_y  = relative_y.to_s
      selector.sc::max_relative_y  = relative_y.to_s
      selector.sc::min_x           = presentation.sc::x
      selector.sc::max_x           = presentation.sc::x
      selector.sc::min_y           = presentation.sc::y
      selector.sc::max_y           = presentation.sc::y

      selector.sc::min_width       = presentation.sc::width
      selector.sc::max_width       = presentation.sc::width
      selector.sc::min_height      = presentation.sc::height
      selector.sc::max_height      = presentation.sc::height
      selector.sc::min_font_size   = presentation.sc::font_size
      selector.sc::max_font_size   = presentation.sc::font_size
      selector.sc::min_font_weight = presentation.sc::font_weight
      selector.sc::max_font_weight = presentation.sc::font_weight
      selector.sc::font_family     = presentation.sc::font_family
      
      selector
    end
  end
end