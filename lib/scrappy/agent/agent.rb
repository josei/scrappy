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

    def self.create args={}
      if (args[:agent] || Options.agent) == :visual
        require 'scrappy/agent/visual_agent'
        VisualAgent.new args
      else
        require 'scrappy/agent/blind_agent'
        BlindAgent.new args
      end
    end

    attr_accessor :id, :output, :content_type, :status, :options, :kb

    def initialize args={}
      super()
      @id = args[:id] || Agent.pool.keys.size
      Agent.pool[@id] = self
      @kb = args[:kb] || Options.kb
      @options = Options.clone
      @repository = args[:repository] || Options.repository
      @time = Time.now.min*100 + Time.now.sec
    end

    def request http_method, uri, inputs={}, depth=options.depth
      synchronize do
        uri = "#{uri}.com" if uri =~ /\A\w+\Z/
        uri = "http://#{uri}" if uri.index(/\A\w*:/) != 0

        # Perform the request
        if http_method == :get
          self.uri = uri
          return RDF::Graph.new unless self.html_data?
        else
          raise Exception, 'POST requests not supported yet'
        end

        # Adds tags including visual information
        add_visual_data! if options.referenceable

        # Checks if using a Sesame repository
        triples = nil

        # Checks if a repository if being used
        if @repository != nil
          # Checks if there is any previous extraction within the last 15 minutes
          context_list = Nokogiri::XML(@repository.get_context)
          context_s = @repository.process_contexts(context_list, uri)

          # Extract data
          triples = nil
          if context_s.empty?
            #Extracts from the uri
            triples = extract self.uri, html, options.referenceable

            #Checks if the extraction returns nothing
            if triples.empty?
            
              #Creates a triple to indicate that nothing was extracted from the uri
              ntriples =  (RDF::Graph.new([[Node(uri), Node("sc:extraction"), Node("sc:Empty")]])).serialize(:ntriples)

              #Adds data to sesame
              result = @repository.post_data(ntriples,uri)
            else
              ntriples =  RDF::Graph.new(triples.uniq).serialize(:ntriples)
              result = @repository.post_data(ntriples,uri)
            end
          else
          
            # Data found in sesame. Asking for it
            ntriples = @repository.get_data(context_s)
            graph = RDF::Parser.parse(:rdf, ntriples)
            graph[Node(uri)].sc::extraction=[]
            triples = graph.triples
          end
        else
          # Extracts data without using a repository
          triples = extract self.uri, html, options.referenceable
        end
        
        # Iterate through subresources
        if depth > 0
          uris = (triples.map{|t| [t[0],t[2]]}.flatten-[Node(self.uri)]).uniq.select{|n| n.is_a?(RDF::Node) and   n.id.is_a?(URI)}.map(&:to_s)
          Agent.process(uris, :depth=>depth-1).each { |result| triples += result }
        end
        RDF::Graph.new(triples.uniq)
      end
    end

    def proxy http_method, uri, inputs={}, format=options.format, depth=options.depth
      synchronize do
        if @status == :redirect and uri == self.uri
          @status = :ok
        else
          @output = request(http_method, uri, inputs, depth).serialize(format)
          @content_type = ContentTypes[format] || 'text/plain'
          @status = if self.html_data?
            self.uri == uri ? :ok : :redirect
          else
            :error
          end
        end
        
        @output
      end
    end

    # Method used when consuming a list of uris
    def process uri, args={}
      sleep 0.001 * options.delay.to_f
      request(:get, uri, {}, args[:depth]).triples
    end
  end
end
