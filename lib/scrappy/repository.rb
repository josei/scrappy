module Scrappy
  class Repository
    include MonitorMixin
  
    def initialize(host, rep, web)
      super()
      @host = host
      @rep = rep
      @web = web
      @format = "ntriples"
    end
    
    #Extract the data in sesame from the indicated repositories
    def get_data(contexts = ["all"])
      synchronize do
        #Prepare the URL to request the data
        dir = "#{@host}openrdf-sesame/repositories/#{@rep}/statements?#{prepare_req_contexts(contexts)}"
  
        #Ask for the data
        RestClient.get dir, :content_type=>'text/plain'
      end
	 	end

	  #Extract the list of the sesame contexts
    def get_context
      synchronize do
        #The URL to get the context list from sesame
        dir = "#{@host}openrdf-sesame/repositories/#{@rep}/contexts"

        #Ask for the context list
        RestClient.get dir, :content_type=>'application/sparql-results+xml'
      end
    end

    #Add data to sesame without removing the previous data
    def post_data(data, uri)
      synchronize do
        #Prepare the dir to connect with the repository
        dir = "#{@host}openrdf-sesame/repositories/#{@rep}/statements?context=%3C#{CGI::escape(uri)}:#{get_date.to_s}%3E"
        
        #Adds the data to Sesame
        RestClient.post dir, data, :content_type=>'text/plain'
      end
    end
    
    #Process the list of context, checks if there is any extraction 
    #from the last 15 minutes, and return an array with them. 
    #If there is not any extraction, returns an empty array
    def process_contexts(context_list, uri)
      
      #This return a array with the contexts from the xml data
      #Be careful. The array does NOT include '<' neither '>'
      array = context_list.search("uri").map(&:text)
      
      #The array to return
      dev = []
      array.each do |con|
        datc = context_date(con)

        #Add the context to the array
        dev << ["%3C#{CGI::escape(con)}%3E"] if (CGI::escape(con).include?(CGI::escape(uri)) && check_date(datc))
      end
      return dev
    end

    protected
    
    #Check if the context date is within the last five minutes
    def check_date(datc)
      result = false
      result = true if ((get_date - datc) <= 15)
      return result
    end
    
    #Gets the  date to add to the context
    def get_date
      return Time.now.year * 100000000 + Time.now.month * 1000000 + Time.now.day * 10000 + Time.now.hour * 100 + Time.now.min
    end
    
    #Process the context and return a integer with the date
    def context_date(context)
      array = context.split(':')
      date = array[array.length - 1 ]
      date.delete('>', '%3E')
      date.delete("%3E")
      return date.to_i
    end

    #Make the contexts to add to the request
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
  end
end
