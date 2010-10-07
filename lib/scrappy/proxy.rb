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
      def process_request http_method
        agent.proxy http_method, request.env["REQUEST_URI"], @input

        case agent.status
        when :redirect
          redirect agent.uri
        when :ok
          @headers['Content-Type'] = agent.content_type
          agent.output
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
