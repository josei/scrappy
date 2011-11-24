# -*- encoding: utf-8 -*-
module Sc
  class Selector
    include RDF::NodeProxy
    include Scrappy::Formats
    
    def select doc
      if sc::debug.first=="true" and Scrappy::Agent::Options.debug and
        (Scrappy::Agent::Options.debug_key.nil? or doc[:value].downcase.include?(Scrappy::Agent::Options.debug_key) )
        
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

      if sc::boolean.first=="true"
        results = results.map do |r|
          affirmations = ["yes", "true"]
          negations = ["no", "none", "false", "-", "--"]
          no  = negations.include?(r[:value].gsub("\302\240"," ").strip.downcase)
          yes = affirmations.include?(r[:value].gsub("\302\240"," ").strip.downcase)
          if no
            value = "false" 
          elsif yes
            value = "true"
          else
            value = :remove
          end
          r.merge :value=>value
        end
        results = results.select{ |r| r[:value] != :remove }
      end
      if sc::normalize_max.first
        max = sc::normalize_max.first.to_f
        min = sc::normalize_min.first.to_f
        results.each { |r| r[:value] = ((r[:value].to_f-min) / (max-min)).to_s }
      end
      if sc::nonempty.first=="true"
        results = results.select{ |r| r[:value].gsub("\302\240"," ").strip!=""}
      end
      
      if sc::debug.first=="true" and Scrappy::Agent::Options.debug and
        (Scrappy::Agent::Options.debug_key.nil? or doc[:value].downcase.include?(Scrappy::Agent::Options.debug_key) )
        
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