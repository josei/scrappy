module Scrappy
  module Optimizer
    # Iterates through a knowledge base and tries to merge and generalize
    # selectors whenever the output of the resulting kb is the same
    def optimize kb, sample
      # Get the output only once
      output = RDF::Graph.new extract(sample[:uri], sample[:html], kb)

      # Build an array of fragments
      root_fragments = kb.find(nil, Node('rdf:type'), Node('sc:Fragment')) - kb.find([], Node('sc:subfragment'), nil)
      fragments = []; root_fragments.each { |f| fragments << kb.node(Node(f.id, RDF::Graph.new(f.all_triples))) }

      # Parse the document
      doc = { :uri=>sample[:uri], :content=>Nokogiri::HTML(sample[:html], nil, 'utf-8') }

      begin
        changed, fragments = optimize_once fragments, doc, output
      end until !changed
      
      graph = RDF::Graph.new
      fragments.each { |fragment| graph << fragment }
      
      graph
    end
    
    protected
    # Tries to optimize a set of fragments.
    # Returns true if there were changes, false otherwise,
    # and the new fragments as the second array element
    def optimize_once fragments, doc, output
      fragments.each do |fragment1|
        fragments.each do |fragment2|
          next if fragment1 == fragment2
          new_fragment = mix_if_gain(fragment1, fragment2, doc, output)
          
          # End if a new fragment was created
          if new_fragment
            return [true, fragments - [fragment1] - [fragment2] + [new_fragment]]
          end
        end
      end
      [false, fragments]
    end
    
    def mix_if_gain fragment1, fragment2, doc, output
      # Won't get gain if the fragment does not produce the same kind of RDF resource
      return if !fragment1.sc::type.equivalent?(fragment2.sc::type) or
                !fragment1.sc::relation.equivalent?(fragment2.sc::relation) or
                !fragment1.sc::superclass.equivalent?(fragment2.sc::superclass) or
                !fragment1.sc::sameas.equivalent?(fragment2.sc::sameas) or
                 fragment1.sc::identifier.size != fragment2.sc::identifier.size
      
      # Build new fragment
      new_fragment = Node(nil)
      new_fragment.rdf::type      = fragment1.rdf::type
      new_fragment.sc::type       = fragment1.sc::type
      new_fragment.sc::relation   = fragment1.sc::relation
      new_fragment.sc::superclass = fragment1.sc::superclass
      new_fragment.sc::sameas     = fragment1.sc::sameas
      
      # sc:selector
      selector = generalize_selectors(fragment1.sc::selector + fragment2.sc::selector)
      new_fragment.graph       << selector
      new_fragment.sc::selector = selector
      
      # sc:identifier
      if fragment1.sc::identifier.first
        selector = generalize_selectors(fragment1.sc::identifier + fragment2.sc::identifier)
        new_fragment.graph         << selector
        new_fragment.sc::identifier = selector
      end
      
      # sc:subfragment
      all_subfragments = fragment1.sc::subfragment + fragment2.sc::subfragment
      all_subfragments.map { |sf| [sf.sc::type.sort_by(&:to_s), sf.sc::relation.sort_by(&:to_s)] }.uniq.each do |types, relations|
        subfragments = all_subfragments.select do |sf|
          sf.sc::type.sort_by(&:to_s)     == types and
          sf.sc::relation.sort_by(&:to_s) == relations
        end
      end
      
      # Check new output
      separate_output1 = fragment1.extract_graph :doc=>doc
      separate_output2 = fragment2.extract_graph :doc=>doc
      separate_output  = separate_output1.merge separate_output2
      new_output       = new_fragment.proxy.extract_graph :doc=>doc
      
      # Check if the output with the new fragment is a subset of the full output
      # and if the output of the fragments alone is a subset of the output of the new
      # fragment. This way we ensure the output is the same without using all the
      # fragments that are available in the knowledge base.
      new_fragment.proxy # if output.contains?(new_output) and new_output.contains?(separate_output)
    end
    
    def generalize_selectors selectors
      selector = Node(nil)
      selector.rdf::type           = Node('sc:VisualSelector')
      selector.sc::min_relative_x  = selectors.map { |s| s.sc::min_relative_x.map(&:to_i) }.flatten.min.to_s
      selector.sc::max_relative_x  = selectors.map { |s| s.sc::max_relative_x.map(&:to_i) }.flatten.max.to_s
      selector.sc::min_relative_y  = selectors.map { |s| s.sc::min_relative_y.map(&:to_i) }.flatten.min.to_s
      selector.sc::max_relative_y  = selectors.map { |s| s.sc::max_relative_y.map(&:to_i) }.flatten.max.to_s
      selector.sc::min_x           = selectors.map { |s| s.sc::min_x.map(&:to_i) }.flatten.min.to_s
      selector.sc::max_x           = selectors.map { |s| s.sc::max_x.map(&:to_i) }.flatten.max.to_s
      selector.sc::min_y           = selectors.map { |s| s.sc::min_y.map(&:to_i) }.flatten.min.to_s
      selector.sc::max_y           = selectors.map { |s| s.sc::max_y.map(&:to_i) }.flatten.max.to_s
      selector.sc::min_width       = selectors.map { |s| s.sc::min_width.map(&:to_i) }.flatten.min.to_s
      selector.sc::max_width       = selectors.map { |s| s.sc::max_width.map(&:to_i) }.flatten.max.to_s
      selector.sc::min_height      = selectors.map { |s| s.sc::min_height.map(&:to_i) }.flatten.min.to_s
      selector.sc::max_height      = selectors.map { |s| s.sc::max_height.map(&:to_i) }.flatten.max.to_s
      selector.sc::min_font_size   = selectors.map { |s| s.sc::min_font_size.map(&:to_i) }.flatten.min.to_s if selectors.all? { |s| s.sc::min_font_size.first }
      selector.sc::max_font_size   = selectors.map { |s| s.sc::max_font_size.map(&:to_i) }.flatten.max.to_s if selectors.all? { |s| s.sc::max_font_size.first }
      selector.sc::min_font_weight = selectors.map { |s| s.sc::min_font_weight.map(&:to_i) }.flatten.min.to_s if selectors.all? { |s| s.sc::min_font_weight.first }
      selector.sc::max_font_weight = selectors.map { |s| s.sc::max_font_weight.map(&:to_i) }.flatten.max.to_s if selectors.all? { |s| s.sc::max_font_weight.first }
      selector.sc::font_family     = selectors.first.sc::font_family if selectors.map { |s| s.sc::font_family }.flatten.uniq.size == 1
      selector.sc::tag             = selectors.first.sc::tag if selectors.map { |s| s.sc::tag }.flatten.uniq.size == 1
      selector.sc::attribute       = selectors.first.sc::attribute if selectors.map { |s| s.sc::attribute }.flatten.uniq.size == 1

      selector
    end
  end
end