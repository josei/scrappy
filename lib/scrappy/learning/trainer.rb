module Scrappy
  module Trainer
    # Generates visual patterns
    def train *samples
      RDF::Graph.new( samples.inject([]) do |triples, sample|
        triples + train_sample( sample ).triples
      end )
    end

    # Generate XPath fragments
    def train_xpath *samples
      RDF::Graph.new( samples.inject([]) do |triples, sample|
        triples + train_sample(sample, true).triples
      end )
    end

    private
    def train_sample sample, xpath=false
      sample  = sample.merge(:content=>Nokogiri::HTML(sample[:html], nil, 'utf-8'))
      results = RDF::Graph.new extract(sample[:uri], sample[:html], xpath ? Scrappy::Kb.patterns : Scrappy::Kb.extractors, :minimum)

      typed_nodes     = results.find(nil, Node("rdf:type"), [])
      non_root_nodes  = results.find([], [], nil)

      nodes = typed_nodes - non_root_nodes

      superfragment = Node(nil)
      selector      = Node(nil)
      identifier    = Node(nil)
      selector.rdf::type    = Node('sc:UriSelector')
      selector.rdf::value   = sample[:uri]
      identifier.rdf::type  = Node('sc:BaseUriSelector')
      superfragment.rdf::type       = Node('sc:Fragment')
      superfragment.sc::selector    = selector
      superfragment.sc::identifier  = identifier
      superfragment.graph << selector
      superfragment.graph << identifier

      RDF::Graph.new( nodes.inject([]) do |triples, node|
        fragment = fragment_for(node, sample, xpath)
        # Include a superfragment that limits the fragment to a specified URI
        if xpath
          other_triples = [ [superfragment.id, ID('sc:subfragment'), fragment.id] ]
        else
          other_triples = []
        end
        
        triples + fragment.graph.triples + other_triples
      end + (xpath ? superfragment.graph.triples : []) )
    end
    
    def fragment_for node, sample, xpath, parent=nil, parent_path=nil
      fragment = Node(nil)
      node_path = node.sc::source.first.sc::selector.first.sc::path.first
      node.keys.each do |predicate|
        case predicate
        when ID("sc:source") then
          selector = selector_for(node.sc::source.first, sample, xpath, parent, parent_path)
          fragment.graph << selector
          fragment.sc::selector = selector
        when ID("sc:uri") then
          selector = selector_for(node.sc::uri.first.sc::source.first, sample, xpath, node, node_path)
          fragment.graph << selector
          fragment.sc::identifier = selector
        when ID("rdf:type") then
          fragment.sc::type = node.rdf::type
        else
          if node[predicate].map(&:class).uniq.first == RDF::Node
            done = []
            node[predicate].map do |subnode|
              selector = subnode.sc::source.first.sc::selector.first
              next if done.include?( {}.merge(selector) )
              done << {}.merge(selector)

              subfragment = fragment_for(subnode, sample, xpath, node, node_path)
              subfragment.sc::relation = Node(predicate)
              subfragment.sc::min_cardinality = "1"
              subfragment.sc::max_cardinality = "1"
          
              fragment.graph << subfragment
              fragment.sc::subfragment += [subfragment]
            end
          end
        end
      end
      fragment.rdf::type = Node("sc:Fragment")
      
      fragment
    end
    
    def selector_for fragment, sample, xpath=false, parent=nil, parent_path=nil
      fragment_selector = fragment.sc::selector.first
      presentation = fragment.sc::presentation.first
      
      selector = Node(nil)
      
      if xpath
        selector.rdf::type  = Node("sc:XPathSelector")
        selector.rdf::value = path_for fragment_selector.sc::path.first, parent_path, sample
      else
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
  
        selector.sc::tag = ["text"] if presentation.sc::font_family.first
        special_tag      = fragment_selector.sc::tag.select { |tag| ["a","img"].include?(tag) }
        selector.sc::tag = special_tag if special_tag.size > 0
      end

      selector.sc::attribute = fragment_selector.sc::attribute
      
      selector
    end
    
    def path_for path, parent_path, sample
      return "./." if path == parent_path
      return path if ["", "/html", "/html/body"].include?(path)
      
      node = sample[:content].search(path).first
      conditions = []
      if node[:class]
        conditions += node[:class].split(" ").map {|c| "contains(concat(' ',normalize-space(@class),' '),concat(' ','#{c.strip}',' '))" }
      else
        conditions += ["not(@class)"]
      end
      if node[:id]
        conditions += ["contains(@id,'#{node[:id].strip}')"]
      else
        conditions += ["not(@id)"]
      end
      selector = "/#{node.name}[#{conditions * " and "}]"
      index = nil
      results = node.parent.search(".#{selector}")
      results.each_with_index { |n,i| index = i+1 if n.path == path }
      
      previous_path = path.split("/")[0..-2] * "/"
      suffix = results.size > 1  ? "[#{index}]" : ""
      
      path_for(previous_path, parent_path, sample) + selector + suffix
    end
  end
end