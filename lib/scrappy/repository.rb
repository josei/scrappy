module Scrappy
  class Repository < RDF::Repository
    # Processes the list of context, checks if there is any extraction 
    # from the last X minutes, and returns an array with them. 
    # If there is not any extraction, returns an empty array
    def recent_contexts uri, seconds=@options[:time].to_i*60
      return [] unless uri
      contexts.select do |context|
        date = context_date(context)
        date and check_date(date, seconds) and context_uri(context) == uri
      end
    end

    def time
      @options[:time]
    end
    
    protected
    # Checks if the context date is within the indicated time
    def check_date date, seconds
      (Time.now.to_i - date) <= seconds
    end

    # Returns an integer with the date of a given context
    def context_date context
      $1.to_i if context =~ /:(\d+)\Z/
    end

    # Returns the URI of a context
    def context_uri context
      $1 if context =~ /\A(.*):(\d+)\Z/
    end
  end
end