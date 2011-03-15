require 'iconv'

module Scrappy
  module Admin
    def self.registered app
      app.use Rack::MethodOverride
      
      app.get '/' do
        if params[:format] and params[:uri]
          redirect "#{settings.base_uri}/#{params[:format]}/#{simplify_uri(params[:uri])}"
        else
          haml :home
        end
      end
      
      app.get '/javascript' do
        fragments = agent.fragments_for(params[:uri])
        content_type 'application/javascript'
        "window.scrappy_extractor=#{fragments.any?};" + open("#{settings.public}/javascripts/annotator.js").read
      end
      
      app.get '/help' do
        haml :help
      end
      
      app.get '/extractors' do
        @uris = ( Agent::Options.kb.find(nil, Node('rdf:type'), Node('sc:UriSelector')) +
                  Agent::Options.kb.find(nil, Node('rdf:type'), Node('sc:UriPatternSelector')) ).
                  map { |node| node.rdf::value }.flatten.sort.map(&:to_s)
        haml :extractors
      end

      app.post '/extractors' do
        if params[:html]
          # Generate extractor automatically
          iconv = Iconv.new(params[:encoding], 'UTF-8')
          html  = iconv.iconv(params[:html]) 
          puts params[:html]
          puts params[:uri]
          raise Exception, "Automatic generation of extractors is not supported yet"
        else
          # Store the given extractor
          Scrappy::App.add_extractor RDF::Parser.parse(:yarf,params[:rdf])
        end
        redirect "#{settings.base_uri}/extractors"
      end      
      app.delete '/extractors/*' do |uri|
        Scrappy::App.delete_extractor uri
        redirect "#{settings.base_uri}/extractors"
      end
      
      app.get '/samples' do
        @samples = Scrappy::App.samples
        haml :samples
      end
      app.get '/samples/:id' do |id|
        Scrappy::App.samples[id.to_i][:html]
      end
      app.get '/samples/:id/:format' do |id,format|
        sample = Scrappy::App.samples[id.to_i]
        headers 'Content-Type' => Scrappy::Agent::ContentTypes[format.to_sym] || 'text/plain'
        RDF::Graph.new(agent.extract(sample[:uri], sample[:html], :minimum)).serialize(format)
      end
      app.post '/samples' do
        html  = Iconv.iconv('UTF-8', params[:encoding], params[:html]).first
        Scrappy::App.add_sample :html=>html, :uri=>params[:uri], :date=>Time.now
        redirect "#{settings.base_uri}/samples"
      end
      app.delete '/samples/:id' do |id|
        Scrappy::App.delete_sample id.to_i
        redirect "#{settings.base_uri}/samples"
      end
    end
  end
end