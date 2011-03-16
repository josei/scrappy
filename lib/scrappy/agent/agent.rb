module Scrappy
  class Agent
    include MonitorMixin
    include Extractor
    include MapReduce
    include Cached
    include BlindAgent

    Options = OpenStruct.new :format=>:yarf, :format_header=>true, :depth=>0, :delay=>0, :workers=>10
    ContentTypes = { :png => 'image/png', :rdfxml => 'application/rdf+xml',
                     :rdf => 'application/rdf+xml' }

    def self.pool
      @pool ||= {}
    end
    def self.[] id
      pool[id] || Agent.new(:id=>id)
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
      @repository = args[:repository] || Options.repository
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
      elsif @repository
        # Extracts from the repository 
        request_from_repository(request)
      else
        # Perform the request
        request_uncached(request)
      end

      # If previous cache exists, do not cache it again
      unless cache[request]
        # Cache the request
        cache[request]                       = { :time=>Time.now, :response=>triples }
        cache[request.merge(:uri=>self.uri)] = { :time=>Time.now, :response=>triples } if self.uri
      end

      # Enqueue subresources
      # Pages are enqueued without reducing depth
      pages = triples.select { |s,p,o| p==ID("rdf:type") and o==ID("sc:Page") }.map{|s,p,o| s}.select{|n| n.is_a?(Symbol)}

      # All other URIS are enqueued with depth reduced
      uris = if depth != 0
        (triples.map { |s, p, o| [s,o] }.flatten - [ID(self.uri)] - pages).select{|n| n.is_a?(Symbol)}
      else
        []
      end
      
      items = ( pages.map { |uri| {:uri=>uri.to_s, :depth=>[-1, depth].max} } +
                uris.map  { |uri| {:uri=>uri.to_s, :depth=>[-1, depth-1].max} } ).
                uniq.select{ |item| !RDF::ID.bnode?(item[:uri]) }
      
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
      triples.uniq!
      
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
        
        output = response.serialize request[:format], options.format_header
      
        puts 'done!'if options.debug
        
        output
      end

      OpenStruct.new :output => output,
                     :content_type => ContentTypes[request[:format]] || 'text/plain',
                     :uri => self.uri,
                     :status => self.html_data? ? (self.uri == request[:uri] ? :ok : :redirect) : :error
    end

    # Method to observe several webs, and extract the data periodically
    def observe uris
      while true
        time_init = Time.now.to_i
        uris.each do |uri|
          puts "Pinging #{uri}..."
          request :uri=>uri
        end
        time = options.repository.time * 60 - (Time.now.to_i - time_init)
        puts "Sleeping until #{Time.now + time}..."
        sleep time
      end
    end

    private
    def complete_uri uri
      uri = "#{uri}.com" if uri =~ /\A\w+\Z/
      uri = "http://#{uri}" unless uri =~ /\A\w*:/
      uri
    end

    def clean triples
      triples.uniq.select { |s,p,o| p!=ID('rdf:type') or ![ID('sc:Index'), ID('sc:Page')].include?(o) }.
                   select { |s,p,o| p!=Node('rdf:type') or ![Node('sc:Index'), Node('sc:Page')].include?(o) }
    end
    
    # Do the extraction using RDF repository
    def request_from_repository request
      triples = []
      
      # Checks if there is any previous extraction within the last 15 minutes
      contexts = if Options.time
        @repository.recent_contexts(request[:uri], Options.time)
      else
        @repository.recent_contexts(request[:uri])
      end

      if contexts.empty?
        # Extracts data from the uri
        triples = request_uncached request

        if options.debug
          print "Storing into repository #{request[:uri]}..."; $stdout.flush
        end
        
        # Checks if the extraction returned something
        graph = if triples.empty?
          # Creates a triple to indicate that nothing was extracted from the uri
          # This is done because otherwise the context wouldn't be stored
          RDF::Graph.new [ [ID(request[:uri]), ID("sc:extraction"), ID("sc:Empty")] ]
        else
          RDF::Graph.new triples.uniq
        end
        
        # Adds data to sesame
        @repository.data = graph, "#{request[:uri]}:#{Time.now.to_i}"
        @repository.data = graph, "#{self.uri}:#{Time.now.to_i}" if self.uri
        
        puts 'done!' if options.debug
        
        triples
      else
        # Data found in repository. Asking for it
        triples = []
        if options.debug
          print "Retrieving from repository #{request[:uri]}..."; $stdout.flush
        end
        contexts.each do |context|
          graph    = @repository.data(context)
          triples += graph.triples.select{|s,p,o| p!=ID("sc:extraction")}
        end
        puts 'done!' if options.debug
        
        triples
      end
    end
    
    # Extracts from the uri
    def request_uncached request
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
      
      if self.html_data?
        triples = extract(self.uri, html, options.referenceable) # Extract data
        Dumper.dump self.uri, clean(triples), options.format if options.dump # Dump results to disk
        triples
      else
        []
      end
    end
  end
end
