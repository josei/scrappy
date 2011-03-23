module Scrappy
  module Optimizer
    # Iterates through a knowledge base and tries to merge and generalize
    # selectors whenever the output of the new resulting is the same
    def optimize kb, sample
      # Get the output only once
      output = RDF::Graph.new extract(sample[:uri], sample[:html], kb)
      begin
        changes = optimize_once kb, sample, output
      end until !changes
      
      puts kb.serialize(:yarf)
      exit

      kb
    end
    
    protected
    def optimize_once kb, sample, output
      fragments = kb.find(nil, Node('rdf:type'), Node('sc:Fragment'))
      
      fragments.each do |fragment1|
        fragments.each do |fragment2|
          next if fragment1 == fragment2
          new_fragment = mix_if_gain(fragment1, fragment2, sample, output)
          
          # End if a new fragment was created
          if new_fragment
            kb.triples -= fragment1.all_triples + fragment2.all_triples
            kb.triples += new_fragment.all_triples
            return true
          end
        end
      end
      false
    end
    
    def mix_if_gain fragment1, fragment2, sample, output
      new_fragment = mix fragment1, fragment2
      
      separate_output1 = extract(sample[:uri], sample[:html], RDF::Graph.new(fragment1.all_triples))
      separate_output2 = extract(sample[:uri], sample[:html], RDF::Graph.new(fragment2.all_triples))
      separate_output  = RDF::Graph.new(separate_output1 + separate_output2)
      new_output       = RDF::Graph.new extract(sample[:uri], sample[:html], new_fragment.graph)
      
      # Check if the output with the new fragment is a subset of the full output
      # and if the output of the fragments alone is a subset of the output of the new
      # fragment. This way we ensure the output is the same without using all the
      # fragments that are available in the knowledge base.
      new_fragment if output.contains?(new_output) and new_output.contains?(separate_output)
    end
    
    def mix *fragments
      new_fragment = Node(nil)
      new_fragment.rdf::type = fragments.first.rdf::type
      new_fragment.sc::type  = fragments.first.sc::type
      
      # sc:selector
      selector = mix_selector(*fragments.map { |f| f.sc::selector }.flatten)
      new_fragment.graph << selector
      new_fragment.sc::selector = selector
      
      # sc:identifier
      if fragments.all? { |f| f.sc::identifier.first }
        selector = mix_selector(*fragments.map { |f| f.sc::identifier }.flatten)
        new_fragment.graph << selector
        new_fragment.sc::identifier = selector
      end
      
      # sc:subfragment
      all_subfragments = fragments.map { |f| f.sc::subfragment }.flatten
      all_subfragments.map { |sf| [sf.sc::type.sort_by(&:to_s), sf.sc::relation.sort_by(&:to_s)] }.uniq.each do |types, relations|
        subfragments = all_subfragments.select do |sf|
          sf.sc::type.sort_by(&:to_s)      == types and
          sf.sc::relation.sort_by(&:to_s) == relations
        end
      end
      
      new_fragment
    end
    
    def mix_selector *selectors
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