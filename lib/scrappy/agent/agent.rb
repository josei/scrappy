module Scrappy
  class Agent
    include Extractor
    include MonitorMixin
    include Cluster

    Options = OpenStruct.new :format=>:yarf, :depth=>0, :agent=>:blind, :delay=>0
    ContentTypes = { :png => 'image/png', :rdfxml => 'application/rdf+xml',
                     :rdf => 'application/rdf+xml' }

    def self.pool
      @pool ||= {}
    end
    def self.[] id
      pool[id] || Agent.create(:id=>id)
    end
    def self.cache
      @cache ||= {}
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
      @id = args[:id] || Agent.pool.keys.size
      Agent.pool[@id] = self
      @kb = args[:kb] || Options.kb
      @options = Options.clone
    end

    def request args={}
      synchronize do
        depth = args[:depth]
        request = { :method=>:get, :inputs=>{} }.merge :method=>args[:method], :uri=>complete_uri(args[:uri]), :inputs=>args[:inputs]||{}

        # Expire cache
        Agent::cache.keys.each { |req| Agent::cache.delete(req) if Time.now.to_i - Agent::cache[req][:time].to_i > 300 }

        # Lookup in cache
        triples = if Agent::cache[request]
          Agent::cache[request][:response]
        else
          # Perform the request
          if request[:method] == :get
            self.uri = request[:uri]
          else
            raise Exception, 'POST requests not supported yet'
          end
          
          response = if self.html_data?
            add_visual_data! if options.referenceable     # Adds tags including visual information
            extract self.uri, html, options.referenceable # Extract data
          else
            []
          end

          # Cache the request
          Agent::cache[request]                       = { :time=>Time.now, :response=>response }
          Agent::cache[request.merge(:uri=>self.uri)] = { :time=>Time.now, :response=>response } unless self.uri.nil?

          response
        end

        # Iterate through subresources
        if depth > 0
          uris = (triples.map{|t| [t[0],t[2]]}.flatten-[Node(self.uri)]).uniq.select{|n| n.is_a?(RDF::Node) and n.id.is_a?(URI)}.map(&:to_s)
          Agent.process(uris, :depth=>depth-1).each { |result| triples += result }
        end
        
        RDF::Graph.new(triples.uniq)
      end
    end

    def proxy args={}
      synchronize do
        request  = { :method=>:get, :inputs=>{}, :format=>options.format, :depth=>options.depth }.merge(args)

        OpenStruct.new :output => self.request(request).serialize(request[:format]),
                       :content_type => ContentTypes[request[:format]] || 'text/plain',
                       :uri => self.uri,
                       :status => self.html_data? ? (self.uri == request[:uri] ? :ok : :redirect) : :error
      end
    end

    # Method used when consuming a list of uris
    def process uri, args={}
      sleep 0.001 * options.delay.to_f
      request(:method=>:get, :uri=>uri, :depth=>args[:depth]).triples
    end
    
    def complete_uri uri
      uri = "#{uri}.com" if uri =~ /\A\w+\Z/
      uri = "http://#{uri}" if uri.index(/\A\w*:/) != 0
      uri
    end
  end
end
