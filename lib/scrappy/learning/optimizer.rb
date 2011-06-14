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
      @distances = {}
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
          puts 'Successful optimization' if i > 0
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
          puts 'Unsuccessful optimization, rolling back...'
        end
        puts
        puts "Fragments: #{fragments.size}, score: #{score}"
        puts "Trying optimization #{i+=1}..."
        new_fragments = optimize fragments
      end while new_fragments
      puts 'Optimization finished'
      
      fragments
    end
    
    # Tries to perform one optimization in a set of fragments
    def optimize fragments
      fragments.each_with_index do |fragment1, index|
        fragments[0...index].sort_by { |fragment2| distance(fragment1, fragment2) }.each do |fragment2|
          next if @tried.include?([fragment1, fragment2]) or @tried.include?([fragment2, fragment1])
          
          new_fragment = group fragment1, fragment2
          
          @tried << [fragment1, fragment2]

          # End by including the new fragment in the list and returning it
          return fragments - [fragment1] - [fragment2] + [new_fragment] if new_fragment
        end
      end
      return
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
      new_selector = merge(*(fragment1.sc::selector + fragment2.sc::selector))
      new_fragment.sc::selector = new_selector
      new_fragment.graph << new_selector
      
      # sc:identifier
      if fragment1.sc::identifier.first
        new_identifier = merge(*(fragment1.sc::identifier + fragment2.sc::identifier))
        new_fragment.sc::identifier = new_identifier
        new_fragment.graph << new_identifier
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
    
    def signature fragment
      [ fragment.sc::type.map(&:to_sym).to_set,
        fragment.sc::relation.map(&:to_sym).to_set,
        fragment.sc::superclass.map(&:to_sym).to_set,
        fragment.sc::sameas.map(&:to_sym).to_set,
        fragment.sc::identifier.first.nil?,
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
    
    def distance fragment1, fragment2
      return @distances[[fragment1.id, fragment2.id]] if @distances[[fragment1.id, fragment2.id]]
      return 1/0.0 if signature(fragment1) != signature(fragment2)

      # Calculate distances
      distance  = selector_distance(fragment1.sc::selector.first, fragment2.sc::selector.first)
      distance += selector_distance(fragment1.sc::identifier.first, fragment2.sc::identifier.first) if fragment1.sc::identifier.first
      
      # Calculate subfragments' distances
      subfragments2 = fragment2.sc::subfragment
      subdistances  = fragment1.sc::subfragment.map do |subfragment1|
        subfragment2 = subfragments2.select { |f| signature(subfragment1) == signature(f) }.first
        subfragments2.delete subfragment2
        
        subfragment2.nil? ? 500.0 : distance(subfragment1, subfragment2)
      end
      
      final_distance = distance + subdistances.inject(0.0) {|sum,d| sum+d} + subfragments2.size*500.0
      @distances[[fragment1.id, fragment2.id]] = final_distance
      @distances[[fragment2.id, fragment1.id]] = final_distance
    end
    
    def selector_distance selector1, selector2
      distance  = 0.0
      distance += (selector1.sc::min_relative_x.first.to_i - selector2.sc::min_relative_x.first.to_i).abs
      distance += (selector1.sc::max_relative_x.first.to_i - selector2.sc::max_relative_x.first.to_i).abs
      distance += (selector1.sc::min_relative_y.first.to_i - selector2.sc::min_relative_y.first.to_i).abs
      distance += (selector1.sc::max_relative_y.first.to_i - selector2.sc::max_relative_y.first.to_i).abs
      distance += (selector1.sc::min_x.first.to_i - selector2.sc::min_x.first.to_i).abs
      distance += (selector1.sc::max_x.first.to_i - selector2.sc::max_x.first.to_i).abs
      distance += (selector1.sc::min_y.first.to_i - selector2.sc::min_y.first.to_i).abs
      distance += (selector1.sc::max_y.first.to_i - selector2.sc::max_y.first.to_i).abs
      distance += (selector1.sc::min_width.first.to_i - selector2.sc::min_width.first.to_i).abs
      distance += (selector1.sc::max_width.first.to_i - selector2.sc::max_width.first.to_i).abs
      distance += (selector1.sc::min_height.first.to_i - selector2.sc::min_height.first.to_i).abs
      distance += (selector1.sc::max_height.first.to_i - selector2.sc::max_height.first.to_i).abs
      distance += (selector1.sc::min_font_size.first.to_i - selector2.sc::min_font_size.first.to_i).abs * 100
      distance += (selector1.sc::max_font_size.first.to_i - selector2.sc::max_font_size.first.to_i).abs * 100
      distance += (selector1.sc::min_font_weight.first.to_i - selector2.sc::min_font_weight.first.to_i).abs
      distance += (selector1.sc::max_font_weight.first.to_i - selector2.sc::max_font_weight.first.to_i).abs
      distance += 100 if selector1.sc::font_family != selector2.sc::font_family
      distance += 500 if selector1.sc::tag != selector2.sc::tag
      distance
    end
    
    def score fragments, docs
      return 0.0 unless fragments
      docs.inject(0.0) { |sum,doc| fscore(fragments, doc)+sum } / docs.size.to_f
    end
    
    def fscore fragments, doc
      count = RDF::ID.count
      extraction = extract_graph(fragments.map(&:proxy), :doc=>doc).triples
      RDF::ID.count = count # Hack to reduce symbol creation

      correct    = doc[:output]
      metrics(correct, extraction, true).last
    end
    
    def metrics correct, extraction, debug=false
      right      = correct.size - (correct - extraction).size
      
      if debug
        puts "  Wrong triples: \n"   + RDF::Graph.new(extraction - correct).to_ntriples
        puts "  Missing triples: \n" + RDF::Graph.new(correct - extraction).to_ntriples
      end
      
      precision  = extraction.size != 0 ? right/extraction.size.to_f : 1.0
      recall     = correct.size != 0 ? right/correct.size.to_f : 1.0
      
      # Calculate fscore
      fscore = 2.0*(recall*precision)/(precision+recall)
      
      puts "  Fscore: #{fscore}" if debug
      
      [ precision, recall, fscore ]
    end
    
    private
    def short_name fragment
      [ fragment.sc::type.first, fragment.sc::relation.first ].
        compact.
        map { |id| RDF::ID.compress(id) } * ", "
    end
  end
end