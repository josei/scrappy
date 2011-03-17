module Sc
  class Selector
    include RDF::NodeProxy
    include Scrappy::Formats
    
    def select doc
      if sc::debug.first=="true" and Scrappy::Agent::Options.debug
        puts '== DEBUG'
        puts '== Selector:'
        puts node.serialize(:yarf, false)
        puts '== On fragment:'
        puts "URI: #{doc[:uri]}"
        puts "Content: #{doc[:content]}"
        puts "Value: #{doc[:value]}"
      end

      # Process selector
      # Filter method is defined in each subclass
      results = filter doc

      if sc::debug.first=="true" and Scrappy::Agent::Options.debug
        puts "== No results" if results.empty?
        results.each_with_index do |result, i|
          puts "== Result ##{i}:"
          puts "URI: #{result[:uri]}"
          puts "Content: #{result[:content]}"
          puts "Value: #{result[:value].inspect}"
        end
        puts
      end
      
      # Return results if no nested selectors
      return results if sc::selector.empty?

      # Process nested selectors
      results.map do |result|
        sc::selector.map { |s| graph.node(s).select result }
      end.flatten
    end
  end
end