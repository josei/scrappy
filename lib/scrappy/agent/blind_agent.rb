module Scrappy
  class BlindAgent < Agent
    def initialize args={}
      super
      @mechanize = Mechanize.new
      @mechanize.max_history = 20
    end

    def uri
      @loaded ? @mechanize.current_page.uri.to_s : nil
    end

    def uri= uri
      synchronize do
        begin
          @mechanize.get uri
          @loaded = true
        rescue Timeout::Error
          @loaded = false
        rescue
          @loaded = false
        end
      end
    end

    def html_data?
      !uri.nil? and @mechanize.current_page.is_a?(Mechanize::Page)
    end

    def html
      @mechanize.current_page.root.to_html :encoding=>'UTF-8'
    end

    def add_visual_data!
    end
  end
end
