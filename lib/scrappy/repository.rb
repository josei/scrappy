module Scrappy
  class Repository < RDF::Repository

    # Processes the list of context, checks if there is any extraction 
    # from the last 15 minutes, and return an array with them. 
    # If there is not any extraction, returns an empty array
    def process_contexts(context_list, uri)
      
      # This return a array with the contexts from the xml data
      # Be careful: The array does NOT include '<' neither '>'
      dev = []
      (contexts).each do |context|
        datc = context_date(context)
        time_v = (@options[:time].to_i) * 60

        # Adds the context to the array
        dev << context if (context.include?(uri) && check_date(datc, time_v))
      end
      return dev
    end
    
    def process_contexts_period(context_list, uri, time)
      dev=[]
      if uri != nil
        
        # This return a array with the contexts from the xml data
        # Be careful: The array does NOT include '<' neither '>'
        array = contexts
      
        # The array to return
        # This one does include both the '<' and '>'
        array.each do |context|
          datc = context_date(context)

          # Adds the context to the array
          #dev << ["%3C#{context}%3E"] if (context.include?(CGI::escape(uri)) && check_date(datc,time))
          if (context.include?(uri) && check_date(datc,time))
            dev<< context
          end
        end
      end
      return dev
    end

    # Gets the  date to add to the context
    # Deprecated
    def get_date
      return Time.now.year * 100000000 + Time.now.month * 1000000 + Time.now.day * 10000 + Time.now.hour * 100 + Time.now.min
    end
    
    protected
    
    # Checks if the context date is within indicated time
    # Be careful. The time must be expresed in seconds.    
    def check_date(datc, time)
      ((Time.now.to_i - datc) <= time)
    end

    # Processes the context and return a integer with the date
    def context_date(context)
      array = context.split(':')
      date = array[array.length - 1 ]
      date.delete('>', '%3E')
      date.delete("%3E")
      return date.to_i
    end
  end
end
