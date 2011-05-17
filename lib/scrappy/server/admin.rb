require 'iconv'
require 'rack-flash'

module Scrappy
  module Admin
    def self.registered app
      app.set :method_override, true
      app.use Rack::Flash
      
      app.get '/' do
        if params[:format] and params[:uri]
          redirect "#{settings.base_uri}/#{params[:format]}/#{simplify_uri(params[:uri])}"
        else
          haml :home
        end
      end
      
      app.get '/javascript' do
        fragments = agent.fragments_for(Scrappy::Kb.extractors, params[:uri])
        content_type 'application/javascript'
        "window.scrappy_extractor=#{fragments.any?};" + open("#{settings.public}/javascripts/annotator.js").read
      end
      
      app.get '/help' do
        haml :help
      end
      
      # Extractors 
      
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
        flash[:notice] = "Extractor stored"
        redirect "#{settings.base_uri}/extractors"
      end      
      app.delete '/extractors/*' do |uri|
        Scrappy::App.delete_extractor uri
        flash[:notice] = "Extractor deleted"
        redirect "#{settings.base_uri}/extractors"
      end

      # Patterns
      
      app.get '/patterns' do
        @patterns = ( Scrappy::Kb.patterns.find(nil, Node('rdf:type'), Node('sc:Fragment')) -
                      Scrappy::Kb.patterns.find([], Node('sc:subfragment'), nil) )
        haml :patterns
      end

      app.get '/patterns/visual' do
        @patterns = ( Scrappy::Kb.patterns.find(nil, Node('rdf:type'), Node('sc:Fragment')) -
                      Scrappy::Kb.patterns.find([], Node('sc:subfragment'), nil) )
        html = @patterns.map { |pattern| render_fragment(pattern) } * ""
        "<html><body>#{html}</body></html>"
      end

      app.get '/patterns/*' do |id|
        "<html><body>#{render_fragment(Scrappy::Kb.patterns[id])}</body></html>"
      end

      app.delete '/patterns' do
        Scrappy::App.delete_patterns
        flash[:notice] = "Patterns deleted"
        redirect "#{settings.base_uri}/patterns"
      end
      
      app.delete '/patterns/*' do |id|
        Scrappy::App.delete_pattern id
        flash[:notice] = "Pattern deleted"
        redirect "#{settings.base_uri}/patterns"
      end
      
      # Samples
      
      app.get '/samples' do
        @samples = Scrappy::App.samples
        haml :samples
      end
      
      app.get '/samples/:id' do |id|
        Scrappy::App.samples[id.to_i][:html]
      end
      
      app.get '/samples/:id/:kb_type' do |id,kb_type|
        kb = (kb_type == "patterns" ? Scrappy::Kb.patterns : Scrappy::Kb.extractors)
        sample = Scrappy::App.samples[id.to_i]
        headers 'Content-Type' => 'text/plain'
        RDF::Graph.new(agent.extract(sample[:uri], sample[:html], kb, Agent::Options.referenceable)).serialize(:yarf)
      end
      
      app.post '/samples/:id/train' do |id|
        new_extractor = agent.train Scrappy::App.samples[id.to_i]
        Scrappy::App.add_pattern new_extractor
        flash[:notice] = "Training completed"
        redirect "#{settings.base_uri}/samples"
      end
      
      app.get '/samples/:id/optimize' do |id|
        Scrappy::Kb.patterns = agent.optimize_patterns(Scrappy::Kb.patterns, Scrappy::App.samples)
        Scrappy::App.save_patterns Scrappy::Kb.patterns
        flash[:notice] = "Optimization completed"
        redirect "#{settings.base_uri}/samples"
      end

      app.post '/samples' do
        html   = Iconv.iconv('UTF-8', params[:encoding], params[:html]).first
        sample = Scrappy::App.add_sample(:html=>html, :uri=>params[:uri], :date=>Time.now)
        flash[:notice] = "Sample stored"
        redirect "#{settings.base_uri}/samples"
      end
      
      app.delete '/samples/:id' do |id|
        Scrappy::App.delete_sample id.to_i
        flash[:notice] = "Sample deleted"
        redirect "#{settings.base_uri}/samples"
      end
      
      def render_fragment fragment, selected_branch=nil
        label = if fragment.sc::relation.first
          fragment.sc::relation.map {|id| RDF::ID.compress(id)} * ', '
        else
          fragment.sc::type.map {|id| RDF::ID.compress(id)} * ', '
        end
        subfragments = [selected_branch || [:min, :max]].flatten.map do |branch|
          fragment.sc::subfragment.map { |f| render_fragment(f, branch) } * ""
        end * ""

        [selected_branch || [:min, :max]].flatten.map do |branch|
          fragment.sc::selector.map do |selector|
            x,y,w,h,font,size,weight,color = case branch
            when :min then
              [selector.sc::min_relative_x, selector.sc::min_relative_y, selector.sc::min_width, selector.sc::min_height, selector.sc::font_family, selector.sc::min_font_size, selector.sc::min_font_weight, :blue]
            when :max then
              [selector.sc::max_relative_x, selector.sc::max_relative_y, selector.sc::max_width, selector.sc::max_height, selector.sc::font_family, selector.sc::max_font_size, selector.sc::max_font_weight, :red]
            end
            style = "position: absolute; left: #{x}px; top: #{y}px; width: #{w}px; height: #{h}px; font-family: #{font}; font-size: #{size}px; font-weight: #{weight}; border: 1px solid #{color}; color: #555;"
            "<div style='#{style}'>#{label}#{subfragments}</div>"
          end * ""
        end * ""        
      end
      
      app.helpers Admin
    end
  end
end