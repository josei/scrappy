module Scrappy
  class Shell
    def initialize file=nil
      @agent = Agent.create
      @file = file
    end

    def run
      commands = ['get', 'put', 'help']

      Readline.completion_append_character = " "
      Readline.completer_word_break_characters = ""
      Readline.completion_proc = proc { |line| commands.grep(/^#{Regexp.escape(line)}/).sort }

      if @file
        open(@file, 'r').lines.each do |line|
          break if process(line) == :quit
        end
      else
        begin
          line = Readline.readline(bash, true)
          code = process line.nil? ? (puts 'quit' unless Options.quiet; 'quit') : line
        end while code != :quit
      end
    end

    protected
    def process raw_command
      command = raw_command.strip

      code = if command =~ /\Aget\W(.*)\Z/
        puts @agent.proxy :get, $1
        puts ''
      elsif command == 'help'
        puts 'Available commands:'
        puts '  get URL: Visit the specified URL'
        puts '  help: Show this information'
        puts '  quit: Exit scrappy shell'
        puts ''
      elsif command == 'quit'
        :quit
      elsif command == '' or command[0..0] == '#'
        nil
      else
        puts "ERROR: Unknown command '#{command}'"
        puts ''
      end
      code
    end

    def bash
      return '' if Options.quiet
      location = if @agent.uri
        uri = URI::parse(@agent.uri)
        path = uri.path.to_s
        path = path[0..0] + "..." + path[-16..-1] if path.size > 20
        if uri.query
          query = "?" + uri.query 
          query = "?..." + query[-10..-1] if query.size > 13
        else
          query = ""
        end
        "#{uri.base}#{path}#{query}"
      else
        ''
      end
      "#{location}$ "
    end
  end
end
