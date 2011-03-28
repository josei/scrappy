module Scrappy
  module Optimizer
    # Iterates through a knowledge base and tries to merge and generalize
    # selectors whenever the output of the resulting kb is the same
    def optimize_patterns kb, sample
      # Build an array of fragments
      root_fragments = kb.find(nil, Node('rdf:type'), Node('sc:Fragment')) - kb.find([], Node('sc:subfragment'), nil)
      fragments = []; root_fragments.each { |f| fragments << kb.node(Node(f.id, RDF::Graph.new(f.all_triples))) }

      # Parse the document
      doc = { :uri=>sample[:uri], :content=>Nokogiri::HTML(sample[:html], nil, 'utf-8') }

      # Optimize the fragment
      fragments = optimize fragments, :docs=>[doc]
      
      graph = RDF::Graph.new
      fragments.each { |fragment| graph << fragment }
      
      graph
    end
    
    protected
    # Tries to optimize a set of fragments
    def optimize fragments, options
      # Tries to iterate until no changes are made
      @tried = []
      new_fragments = fragments.map{ |f| f.proxy(Node('sc:Fragment')) }
      begin
        fragments = new_fragments
        new_fragments = optimize_once fragments, options
      end until fragments == new_fragments
      fragments
    end
    
    # Tries to perform one optimization of two fragments out of a set of fragments
    def optimize_once fragments, options
      docs = options[:docs]
      fragments.each do |fragment1|
        fragments.each do |fragment2|
          next if fragment1 == fragment2
          # Won't get gain if the fragment does not produce the same kind of RDF resource
          next if !fragment1.sc::type.equivalent?(fragment2.sc::type) or
                  !fragment1.sc::relation.equivalent?(fragment2.sc::relation) or
                  !fragment1.sc::superclass.equivalent?(fragment2.sc::superclass) or
                  !fragment1.sc::sameas.equivalent?(fragment2.sc::sameas) or
                   fragment1.sc::identifier.size != fragment2.sc::identifier.size

          next if @tried.include?([fragment1, fragment2])
          next if @tried.include?([fragment2, fragment1])

          @tried << [fragment1, fragment2]

          # Get mappings without mixing fragments
          old_mappings = []
          docs.each do |doc|
            old_mappings += fragment1.all_mappings(:doc=>doc)
            old_mappings += fragment2.all_mappings(:doc=>doc)
          end
          old_docs = old_mappings.map { |mapping| mapping[:doc] }
          
          # Get mixed fragment
          new_fragment = mix(fragment1, fragment2, options)
          
          # Get new mappings
          new_mappings = []
          docs.each { |doc| new_mappings += new_fragment.mappings(:doc=>doc) }
          new_docs = new_mappings.map { |mapping| mapping[:doc] }

          # Optimize subfragments
          subfragments = optimize(fragment1.sc::subfragment + fragment2.sc::subfragment, options.merge(:docs=>new_docs))
          subfragments.each { |subfragment| new_fragment.graph << subfragment }
          new_fragment.sc::subfragment = subfragments.map &:node

          # End if the new fragment returns the same results
          if true
            return fragments - [fragment1] - [fragment2] + [new_fragment]
          end
        end
      end
      fragments
    end
    
    def mix fragment1, fragment2, options
      docs = options[:docs]
      
      # Build new fragment
      new_fragment = Node(nil).proxy(Node('sc:Fragment'))
      new_fragment.rdf::type      = Node('sc:Fragment')
      new_fragment.sc::type       = fragment1.sc::type
      new_fragment.sc::relation   = fragment1.sc::relation
      new_fragment.sc::superclass = fragment1.sc::superclass
      new_fragment.sc::sameas     = fragment1.sc::sameas

      # If fragments share the same parent, cardinality has to increase
      # Otherwise, they might map the same subdocument, so cardinality
      # limits are made more general.
      if fragment1.sc::superfragment.first and fragment1.sc::superfragment == fragment2.sc::superfragment
        new_fragment.sc::min_cardinality = (fragment1.sc::min_cardinality.first.to_i + fragment2.sc::min_cardinality.first.to_i).to_s
        new_fragment.sc::max_cardinality = (fragment1.sc::max_cardinality.first.to_i + fragment2.sc::max_cardinality.first.to_i).to_s
      else
        new_fragment.sc::min_cardinality = [fragment1.sc::min_cardinality.first.to_i, + fragment2.sc::min_cardinality.first.to_i].min.to_s
        new_fragment.sc::max_cardinality = [fragment1.sc::max_cardinality.first.to_i, + fragment2.sc::max_cardinality.first.to_i].max.to_s
      end
      
      # sc:selector
      selector = generalize(fragment1.sc::selector + fragment2.sc::selector)
      new_fragment.graph       << selector
      new_fragment.sc::selector = selector
      
      # sc:identifier
      if fragment1.sc::identifier.first
        selector = generalize(fragment1.sc::identifier + fragment2.sc::identifier)
        new_fragment.graph         << selector
        new_fragment.sc::identifier = selector
      end

      # All new nodes are expected to be inconsistent after performing
      # subfragments' extractions. Otherwise, if new nodes are consistent, it means
      # the output from the mixed fragment is different from the separate fragments
      # and therefore the generalization has failed, so no mixed fragment is returned
      new_fragment
    end

    # Generalize a set of selectors
    def generalize selectors
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