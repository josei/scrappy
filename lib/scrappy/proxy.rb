require 'sinatra'
require 'thin'

module Scrappy
  class Proxy < Sinatra::Base
    get '*' do
      process_request :get
    end

    post '*' do
      process_request :post
    end

    protected
    def process_request method
      response = agent.proxy :method=>method, :uri=>request.env['REQUEST_URI'], :inputs=>params

      case response.status
      when :redirect
        redirect response.uri
      when :ok
        headers 'Content-Type' => response.content_type
        response.output
      else
        status 500
        "Internal error"
      end
    end

    def agent
      Scrappy::Agent[request.ip]
    end
  end
end
