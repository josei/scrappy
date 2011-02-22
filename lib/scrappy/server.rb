require 'camping'
require 'camping/session'
require 'open3'

Camping.goes :Scrappy

module Scrappy
  set :secret, "1a36591bceec49c832079e270d7e8b73"
  include Camping::Session

  module Controllers
    class Index
      def get
        mab do
          html do
            head {}
            body do
              h1 "Scrappy Web Server"
              p  "Use following URL format: http://[host]/[format]/[url]"
              p  do
                "For example: " + a("http://localhost:3434/rdfxml/http://www.google.com",
                             :href=>"http://localhost:3434/rdfxml/http://www.google.com")
              end
              p do
                "Remember to escape parameters: " +
                "http://www.example.com/~user/%3Ftest%3D1%26test1%3D2<br/> or<br/> " +
                "http%3A%2F%2Fwww.example.com%2F~user%2F%3Ftest%3D1%26test1%3D2<br/>" +
                "instead of<br/> http://www.example.com/~user/?test=1&test1=2"
              end
              p do
                "Available formats are png, yarf, rdfxml, ntriples, turtle, json, jsonrdf, ejson"
              end
            end
          end
        end
      end
    end

    class Extract < R '/(\w+)/(.+)'
      include InputEscaping

      def get format, url
        process_request :get, format, url
      end

      def post format, url
        process_request :post, format, url
      end

      protected
      def process_request method, format, url
        callback = @input['callback']
        response = agent.proxy :method=>method, :uri=>url, :inputs=>@input.reject{|k,v| k=='callback'}, :format=>format.to_sym
        case response.status
        when :redirect
          redirect "/#{format}/#{CGI::escape(response.uri).gsub('%2F','/').gsub('%3A',':')}#{inputs}"
        when :ok
          @headers['Content-Type'] = response.content_type
          callback ? "#{callback}(#{response.output})" : response.output
        else
          @status = 500
          'Error'
        end
      end

      def agent
        return @agent if @agent
        if @state[:agent].nil? || @state[:token] != SESSION_TOKEN
          @state[:token] = SESSION_TOKEN
          @state[:agent] = Scrappy::Agent.create.id
        end
        @agent = Scrappy::Agent[@state[:agent]]
      end
    end
  end
end
