module Scrappy
  class Agent
    include MonitorMixin
    include Extractor
    include MapReduce
    include Cached

    Options = OpenStruct.new :format=>:yarf, :format_header=>true, :depth=>0, :agent=>:blind, :delay=>0, :workers=>10
    ContentTypes = { :png => 'image/png', :rdfxml => 'application/rdf+xml',
                     :rdf => 'application/rdf+xml' }

    def self.pool
      @pool ||= {}
    end
    def self.[] id
      pool[id] || Agent.create(:id=>id)
    end

    def self.create args={}
      if (args[:agent] || Options.agent) == :visual
        require 'scrappy/agent/visual_agent'
        VisualAgent.new args
      else
        require 'scrappy/agent/blind_agent'
        BlindAgent.new args
      end
    end

    attr_accessor :id, :options, :kb

    def initialize args={}
      super()
      @cluster_count   = args[:workers] || Options.workers
      @cluster_options = [ { :referenceable=>Options.referenceable, :agent=>Options.agent,
                             :workers=>1, :window=>false } ]
      @cluster = args[:parent]
      @id = args[:id] || Agent.pool.keys.size
      Agent.pool[@id] = self
      @kb = args[:kb] || Options.kb
      @options = Options.clone
    end

    def map args, queue=nil
      depth = args[:depth] || options.depth
      request = { :method=>args[:method]||:get, :uri=>complete_uri(args[:uri]), :inputs=>args[:inputs]||{} }

      # Expire cache
      cache.expire! 300 # 5 minutes

      # Lookup in cache
      triples = if cache[request]
        puts "Retrieving cached #{request[:uri]}...done!" if options.debug
        
        cache[request][:response]
      else
        # Perform the request
        
        sleep 0.001 * options.delay.to_f # Sleep if requested

        if options.debug
          print "Opening #{request[:uri]}..."; $stdout.flush
        end

        if request[:method] == :get
          self.uri = request[:uri]
        else
          raise Exception, 'POST requests not supported yet'
        end
        
        puts 'done!' if options.debug
        
        response = if self.html_data?
          add_visual_data! if options.referenceable                     # Adds tags including visual information
          extraction = extract self.uri, html, options.referenceable       # Extract data
          Dumper.dump self.uri, clean(extraction), options.format if options.dump # Dump results to disk
          extraction
        else
          []
        end

        # Cache the request
        cache[request]                       = { :time=>Time.now, :response=>response }
        cache[request.merge(:uri=>self.uri)] = { :time=>Time.now, :response=>response } unless self.uri.nil?

        response
      end

      # Enqueue subresources
      # Pages are enqueued without reducing depth
      pages = triples.select { |s,p,o| p==Node("rdf:type") and o==Node("sc:Page") }.map{|s,p,o| s}.select{|n| n.is_a?(RDF::Node) and n.id.is_a?(URI)}

      # All other URIS are enqueued with depth reduced
      uris = if depth != 0
        (triples.map { |s, p, o| [s,o] }.flatten - [Node(self.uri)] - pages).select{|n| n.is_a?(RDF::Node) and n.id.is_a?(URI)}
      else
        []
      end
      
      items = (pages.map { |uri| {:uri=>uri.to_s, :depth=>[-1, depth].max} } + uris.map { |uri| {:uri=>uri.to_s, :depth=>[-1, depth-1].max} }).uniq
      
      items.each { |item| puts "Enqueuing (depth = #{item[:depth]}): #{item[:uri]}" } if options.debug
      
      if queue.nil?
        triples += process items
      else
        items.each { |item| queue.push_unless_done item }
      end

      triples unless options.dump
    end
    
    def reduce results
      return [] if options.dump
      
      if options.debug
        print "Merging results..."; $stdout.flush
      end
      
      triples = []; results.each { |result| triples += result }
      
      puts 'done!'if options.debug
      
      triples
    end

    def request args={}
      RDF::Graph.new clean(map(args) || [])
    end

    def proxy args={}
      request  = { :method=>:get, :inputs=>{}, :format=>options.format, :depth=>options.depth }.merge(args)
      
      response = self.request(request)
      
      output = if options.dump
        ""
      else
        if options.debug
          print "Serializing..."; $stdout.flush
        end
        
        output = response.serialize request[:format], @options.format_header
      
        puts 'done!'if options.debug
        
        output
      end

      OpenStruct.new :output => output,
                     :content_type => ContentTypes[request[:format]] || 'text/plain',
                     :uri => self.uri,
                     :status => self.html_data? ? (self.uri == request[:uri] ? :ok : :redirect) : :error
    end

    def complete_uri uri
      uri = "#{uri}.com" if uri =~ /\A\w+\Z/
      uri = "http://#{uri}" if uri.index(/\A\w*:/) != 0
      uri
    end
    
    def clean triples
      triples.uniq.select { |s,p,o| p!=Node('rdf:type') or ![Node('sc:Index'), Node('sc:Page')].include?(o) }
    end
  end
end
