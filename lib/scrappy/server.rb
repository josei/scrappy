require 'sinatra'
require 'thin'
require 'haml'

module Scrappy
  class Server < Sinatra::Base
    enable :sessions
    set    :views, File.dirname(__FILE__) + '/views'

    get '/' do
      haml :home
    end

    get '/:format/*' do
      process_request :get, params[:format], params[:splat] * "/", params[:callback]
    end

    post '/:format/*' do
      process_request :post, params[:format], params[:splat] * "/", params[:callback]
    end

    protected
    def process_request method, format, url, callback
      response = agent.proxy :method=>method, :uri=>url, :inputs=>inputs, :format=>format.to_sym
      case response.status
      when :redirect
        redirect "/#{format}/#{CGI::escape(response.uri).gsub('%2F','/').gsub('%3A',':')}#{textual_inputs}"
      when :ok
        headers 'Content-Type' => response.content_type
        callback ? "#{callback}(#{response.output})" : response.output
      else
        status 500
        "Internal error"
      end
    end

    def agent
      return @agent if @agent
      if session[:agent].nil? || session[:token] != SESSION_TOKEN
        session[:token] = SESSION_TOKEN
        session[:agent] = Scrappy::Agent.create.id
      end
      @agent = Scrappy::Agent[session[:agent]]
    end

    def inputs
      params.reject{|k,v| ['callback', 'splat', 'format']}
    end
    
    def textual_inputs
      return '' if inputs.empty?
      "?" + (inputs.map{|k,v| "#{CGI.escape(k)}=#{CGI.escape(v)}"}*'')
    end
  end
end