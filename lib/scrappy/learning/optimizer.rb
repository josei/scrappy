require 'set'

module Scrappy
  module Optimizer
    # Iterates through a knowledge base and tries to merge and generalize
    # selectors whenever the output of the resulting kb is the same
    def optimize_patterns kb, samples
      # Build an array of fragments
      root_fragments = kb.find(nil, Node('rdf:type'), Node('sc:Fragment')) - kb.find([], Node('sc:subfragment'), nil)
      fragments = []
      pool      = {}
      root_fragments.each do |f|
        fragment = Node(f.id, RDF::Graph.new(f.all_triples))
        fragment.graph.pool = pool
        fragments << fragment
      end

      # Parse the documents
      docs = samples.map do |sample|
        output  = extract(sample[:uri], sample[:html], Scrappy::Kb.extractors)
        content = Nokogiri::HTML(sample[:html], nil, 'utf-8')
        { :uri=>sample[:uri], :content=>content, :output=>output }
      end

      # Optimize the fragments
      @tried = []
      fragments = optimize_all fragments, docs
      RDF::Graph.new(fragments.inject([]) { |triples, fragment| triples += fragment.all_triples })
    end
    
    protected
    # Optimizes a set of fragments
    def optimize_all fragments, docs
      # Iterates until no changes are made
      new_fragments = fragments
      score         = 0.0
      i             = 0
      last_save     = 0
      begin
        new_score = score(new_fragments, docs)
        if new_score >= score # Improvement after optimization?
          puts 'Succesful optimization' if i > 0
          score     = new_score
          fragments = new_fragments
          
          # Save to disk
          if (Time.now - last_save).to_i > 60 and i > 0
            print "Saving..."; $stdout.flush
            Scrappy::App.save_patterns fragments
            puts "done!"

            last_save = Time.now
          end
        else
          puts 'Unsuccesful optimization, rolling back...'
        end
        puts
        puts "Fragments: #{fragments.size}"
        puts "Trying optimization #{i+=1}..."
        new_fragments = optimize fragments
      end while new_fragments
      puts 'Optimization finished'
      
      fragments
    end
    
    # Tries to perform one optimization in a set of fragments
    def optimize fragments
      fragments.each do |fragment1|
        fragments.each do |fragment2|
          next if @tried.include?([fragment1, fragment2]) or @tried.include?([fragment2, fragment1])
          
          new_fragment = if fragment1 == fragment2
            simplify fragment1
          else
            group fragment1, fragment2
          end

          @tried << [fragment1, fragment2]

          # End by including the new fragment in the list and returning it
          return fragments - [fragment1] - [fragment2] + [new_fragment] if new_fragment
        end
      end
      return
    end

    # Tries to perform one simplification inside a fragment
    def simplify fragment
      new_fragment            = fragment.rename
      new_fragment.graph.pool = fragment.graph.pool
      
      # Attempts to perform one optimization in the subfragments
      subfragments = optimize new_fragment.sc::subfragment

      if subfragments
        # Removes old subfragments
        new_fragment.sc::subfragment.each { |subfragment| new_fragment.graph.delete subfragment }
        # Adds new subfragments
        subfragments.each { |subfragment| new_fragment.graph << subfragment }
        new_fragment.sc::subfragment = subfragments
      else
        # If subfragments cannot be optimized, try to optimize selectors or identifiers
        if !generalize!(new_fragment, Node('sc:selector')) and
           !generalize!(new_fragment, Node('sc:identifier'))
          return
        end
      end
      
      puts "  new fragment #{new_fragment} (#{short_name(new_fragment)}) out of #{fragment}"
      
      new_fragment
    end

    # Groups two fragments into one
    def group fragment1, fragment2, siblings=true
      return unless signature(fragment1) == signature(fragment2)

      new_fragment                = Node(nil)
      new_fragment.rdf::type      = Node("sc:Fragment")
      new_fragment.graph.pool     = fragment1.graph.pool
      new_fragment.sc::type       = fragment1.sc::type
      new_fragment.sc::relation   = fragment1.sc::relation
      new_fragment.sc::superclass = fragment1.sc::superclass
      new_fragment.sc::sameas     = fragment1.sc::sameas

      if fragment1.sc::min_cardinality.first and fragment2.sc::min_cardinality.first
        if siblings
          new_fragment.sc::min_cardinality = (fragment1.sc::min_cardinality.first.to_i + fragment2.sc::min_cardinality.first.to_i).to_s
        else
          new_fragment.sc::min_cardinality = [fragment1.sc::min_cardinality.first.to_i, + fragment2.sc::min_cardinality.first.to_i].min.to_s
        end
      end
      if fragment1.sc::max_cardinality.first and fragment2.sc::max_cardinality.first
        if siblings
          new_fragment.sc::max_cardinality = (fragment1.sc::max_cardinality.first.to_i + fragment2.sc::max_cardinality.first.to_i).to_s
        else
          new_fragment.sc::max_cardinality = [fragment1.sc::max_cardinality.first.to_i, + fragment2.sc::max_cardinality.first.to_i].max.to_s
        end
      end

      # sc:selector
      selectors = fragment1.sc::selector + fragment2.sc::selector
      new_fragment.sc::selector = selectors.map do |selector|
        new_selector = Node(selector)
        selector.each { |k,v| new_selector[k] = v }
        new_fragment.graph << new_selector
        new_selector
      end
      
      # sc:identifier
      identifiers = fragment1.sc::identifier + fragment2.sc::identifier
      new_fragment.sc::identifier = identifiers.map do |selector|
        new_selector = Node(selector)
        selector.each { |k,v| new_selector[k] = v }
        new_fragment.graph << new_selector
        new_selector
      end
      
      subfragments = mix(fragment1.sc::subfragment, fragment2.sc::subfragment)
      return unless subfragments
      
      subfragments.each { |f| new_fragment.graph << f }
      new_fragment.sc::subfragment = subfragments
      
      puts "  new fragment #{new_fragment} (#{short_name(new_fragment)}) out of #{fragment1} and #{fragment2}"

      new_fragment
    end

    # Mixes and aligns two set of fragments
    def mix fragments1, fragments2
      return unless fragments1.size == fragments2.size

      # Build new fragments
      used_fragments = []
      fragments1.map do |fragment1|
        fragment2 = fragments2.select { |fragment2| signature(fragment1) == signature(fragment2) }.first
        return unless fragment2
        return if used_fragments.include?(fragment2)

        used_fragments << fragment2
        
        group fragment1, fragment2, false
      end
    end

    # Tries to merge a pair of selectors inside a fragment
    # It accepts a property to indicate sc:selector or sc:identifier
    def generalize! fragment, property
      done = false
      selectors = fragment[property]
      return false if selectors.size <= 1
      selectors.each do |selector1|
        selectors.each do |selector2|
          next if selector1 == selector2
          next if @tried.include?([selector1, selector2]) or @tried.include?([selector2, selector1])

          new_selector = merge selector1, selector2

          # Replace the two selectors with the new one
          fragment.graph.delete selector1
          fragment.graph.delete selector2
          fragment.graph << new_selector
          fragment[property] = fragment[property] - [selector1] - [selector2] + [new_selector]
          
          @tried << [selector1, selector2]
          
          puts "  new selector #{new_selector} out of #{selector1} and #{selector2}"

          return true
        end
      end
      false
    end
    
    def signature fragment
      [ fragment.sc::type.map(&:to_sym).to_set,
        fragment.sc::relation.map(&:to_sym).to_set,
        fragment.sc::superclass.map(&:to_sym).to_set,
        fragment.sc::sameas.map(&:to_sym).to_set,
        fragment.sc::identifier.size,
        fragment.sc::subfragment.map { |sf| signature(sf) }.to_set ]
    end
    
    # Merges a set of selectors, returning a new more general one
    def merge *selectors
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
      selector.sc::font_family     = selectors.first.sc::font_family if selectors.map { |s| s.sc::font_family.sort }.uniq.size == 1
      selector.sc::tag             = selectors.first.sc::tag if selectors.map { |s| s.sc::tag.sort }.uniq.size == 1
      selector.sc::attribute       = selectors.first.sc::attribute if selectors.map { |s| s.sc::attribute.sort }.uniq.size == 1

      selector
    end
    
    def score fragments, docs
      return 0.0 unless fragments
      docs.inject(0) { |sum,doc| fscore(fragments, doc)+sum } / docs.size
    end
    
    def fscore fragments, doc
      count = RDF::ID.count
      extraction = extract_graph(fragments.map(&:proxy), :doc=>doc).triples
      RDF::ID.count = count # Hack to reduce symbol creation

      correct    = doc[:output]
      metrics(correct, extraction).last
    end
    
    def metrics correct, extraction
      right      = correct.size - (correct - extraction).size
      
      precision  = extraction.size != 0 ? right/extraction.size.to_f : 1.0
      recall     = correct.size != 0 ? right/correct.size.to_f : 1.0
      
      # Calculate fscore
      fscore = 2.0*(recall*precision)/(precision+recall)
      
      [ fscore, precision, recall ]
    end
    
    private
    def short_name fragment
      [ fragment.sc::type.first, fragment.sc::relation.first ].
        compact.
        map { |id| RDF::ID.compress(id) } * ", "
    end
  end
end