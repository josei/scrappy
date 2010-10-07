# Hack to hide annoying gtk debug messages
old_stderr = $stderr.clone
$stderr.reopen '/dev/null'
require 'scrappy/webkit/webkit'
$stderr = old_stderr

module Scrappy
  class VisualAgent < Agent
    def initialize args={}
      super

      @cv = new_cond

      @webview = Gtk::WebKit::WebView.new
      @webview.signal_connect("load_finished") { synchronize { @cv.signal } }

      @window = Gtk::Window.new
      @window.signal_connect("destroy") { Gtk.main_quit }
      @window.add(@webview)
      @window.set_size_request(1024, 600)
      @window.show_all if args[:window] or (args[:window].nil? and Agent::Options.window)
    end

    def uri
      @webview.uri
    end

    def uri= uri
      synchronize do
        @webview.open uri.to_s
        @cv.wait(60) # 1 minute to open the page
        sleep(1) while !Nokogiri::HTML(html).search("head").empty? and Nokogiri::HTML(html).search("body").empty?
      end
    end

    def html_data?
      uri.to_s != ""
    end

    def html
      js "document.documentElement.outerHTML"
    end
    
    def add_visual_data!
      js """var items = document.documentElement.getElementsByTagName('*');
            var i=0;
            for(var i=0; i<items.length; i++) {
              var item = items[i];
              item.setAttribute('vx', item.offsetLeft)
              item.setAttribute('vy', item.offsetTop)
              item.setAttribute('vw', item.offsetWidth)
              item.setAttribute('vh', item.offsetHeight)
              item.setAttribute('vsize', document.defaultView.getComputedStyle(item, null).getPropertyValue('font-size'))
              item.setAttribute('vweight', document.defaultView.getComputedStyle(item, null).getPropertyValue('font-weight'))
              item.setAttribute('vcolor', document.defaultView.getComputedStyle(item, null).getPropertyValue('color'))
              item.setAttribute('vbcolor', document.defaultView.getComputedStyle(item, null).getPropertyValue('background-color'))
            }"""
    end


    private
    def js code
      old_title = @webview.title
      @webview.execute_script("document.title = JSON.stringify(eval(#{ActiveSupport::JSON.encode(code)}))")
      title = ActiveSupport::JSON.decode(@webview.title)
      @webview.execute_script("document.title = #{ActiveSupport::JSON.encode(old_title)}")
      title
    end
  end
end

Thread.new { Gtk.main }
