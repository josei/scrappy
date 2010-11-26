module Scrappy
  class Repository
    include MonitorMixin
  
    def initialize(r_opt)
      super()

      # Assigns the default value to the nil options
      @options = {"host"=>"http://localhost", "port"=>"8080", "repo"=>"men-ses", "time"=>"15", "format"=>"ntriples"}.merge(r_opt)
    end
    
    # Extracts the data in sesame from the indicated repositories
    def get_data(contexts = ["all"])
      synchronize do
        # Prepares the URL to request the data
        dir = "#{@options["host"]}:#{@options["port"]}/openrdf-sesame/repositories/#{@options["repo"]}/statements?#{prepare_req_contexts(contexts)}"
  
        # Asks for the data
        RestClient.get dir, :content_type=>select_type
      end
	 	end

	  # Gets the list of the sesame contexts
    def get_context
      synchronize do
        # The URL to get the context list from sesame
        dir = "#{@options["host"]}:#{@options["port"]}/openrdf-sesame/repositories/#{@options["repo"]}/contexts"

        # Asks for the context list
        RestClient.get dir, :content_type=>'application/sparql-results+xml'
      end
    end

    # Adds data to sesame without removing the previous data
    def post_data(data, uri)
      synchronize do
        # Prepares the dir to connect with the repository
        dir = "#{@options["host"]}:#{@options["port"]}/openrdf-sesame/repositories/#{@options["repo"]}/statements?context=%3C#{CGI::escape(uri)}:#{get_date.to_s}%3E"

        # Adds the data to Sesame
        RestClient.post dir, data, :content_type=>select_type
      end
    end
    
    # Processes the list of context, checks if there is any extraction 
    # from the last 15 minutes, and return an array with them. 
    # If there is not any extraction, returns an empty array
    def process_contexts(context_list, uri)
      
      # This return a array with the contexts from the xml data
      # Be careful: The array does NOT include '<' neither '>'
      array = context_list.search("uri").map(&:text)
      
      #The array to return
      dev = []
      array.each do |con|
        datc = context_date(con)

        # Adds the context to the array
        dev << ["%3C#{CGI::escape(con)}%3E"] if (CGI::escape(con).include?(CGI::escape(uri)) && check_date(datc))
      end
      return dev
    end

    protected
    
    # Checks if the context date is within indicated time
    def check_date(datc)
      result = false
      result = true if ((get_date - datc) <= @options["time"].to_i)
      return result
    end
    
    # Gets the  date to add to the context
    def get_date
      return Time.now.year * 100000000 + Time.now.month * 1000000 + Time.now.day * 10000 + Time.now.hour * 100 + Time.now.min
    end
    
    # Processes the context and return a integer with the date
    def context_date(context)
      array = context.split(':')
      date = array[array.length - 1 ]
      date.delete('>', '%3E')
      date.delete("%3E")
      return date.to_i
    end

    # Makes the contexts to add to the request
    def prepare_req_contexts(contexts)
      result = ""
      if contexts[0] != nil
        i = 0
        while i < contexts.length
          result += "context=#{contexts[i]}"
          i += 1
          result += "&&" if i != contexts.length
        end
      end
      return result
    end

    # Selects the type of data to send to sesame
    def select_type
      type = case
        when @options["format"] == "rdfxml" then 'application/rdf+xml'
        when @options["format"] == "ntriples" then 'text/plain'
        when @options["format"] == "turtle" then 'application/x-turtle'
        when @options["format"] == "n3" then 'text/rdf+n3'
        when @options["format"] == "trix" then 'application/trix'
        when @options["format"] == "trig" then 'application/x-trig'
        else "Unknown"
      end
      return type
    end
  end
end
