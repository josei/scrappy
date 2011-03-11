module Scrappy
  module Admin
    def self.registered app
      app.get '/' do
        if params[:format] and params[:uri]
          redirect "#{settings.base_uri}/#{params[:format]}/#{simplify_uri(params[:uri])}"
        else
          haml :home
        end
      end
      
      app.get '/help' do
        haml :help
      end
      
      app.get '/kb' do
        @uris = ( Agent::Options.kb.find(nil, Node('rdf:type'), Node('sc:UriSelector')) +
                  Agent::Options.kb.find(nil, Node('rdf:type'), Node('sc:UriPatternSelector')) ).
                  map { |node| node.rdf::value }.flatten.sort.map(&:to_s)
        haml :kb
      end
    end
  end
end