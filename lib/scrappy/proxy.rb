require 'camping'
require 'camping/session'
require 'open3'

Camping.goes :Scrappy

module Scrappy
  module Controllers
    class Index < R '.*'
      include InputEscaping

      def get
        process_request :get
      end

      def post
        process_request :post
      end

      protected
      def process_request method
        response = agent.proxy :method=>method, :uri=>request.env["REQUEST_URI"], :inputs=>@input

        case response.status
        when :redirect
          redirect response.uri
        when :ok
          @headers['Content-Type'] = response.content_type
          response.output
        else
          @status = 500
          'Error'
        end
      end

      def agent
        Scrappy::Agent[@request.env["REMOTE_ADDR"]]
      end
    end
  end
end
