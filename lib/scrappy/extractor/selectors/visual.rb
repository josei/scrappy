module Sc
  class VisualSelector < Selector

    def initialize args={}
      super
      @cache = {}
    end

    def filter doc
      @cache[doc] ||= begin
        # By initializing variables, we avoid getting data from a hash (slow)
        min_relative_x  = (sc::min_relative_x.first.to_i if sc::min_relative_x.first)
        max_relative_x  = (sc::max_relative_x.first.to_i if sc::max_relative_x.first)
        min_relative_y  = (sc::min_relative_y.first.to_i if sc::min_relative_y.first)
        max_relative_y  = (sc::max_relative_y.first.to_i if sc::max_relative_y.first)
        min_x           = (sc::min_x.first.to_i if sc::min_x.first)
        max_x           = (sc::max_x.first.to_i if sc::max_x.first)
        min_y           = (sc::min_y.first.to_i if sc::min_y.first)
        max_y           = (sc::max_y.first.to_i if sc::max_y.first)
        min_width       = (sc::min_width.first.to_i if sc::min_width.first)
        max_width       = (sc::max_width.first.to_i if sc::max_width.first)
        min_height      = (sc::min_height.first.to_i if sc::min_height.first)
        max_height      = (sc::max_height.first.to_i if sc::max_height.first)
        min_font_size   = (sc::min_font_size.first.to_i if sc::min_font_size.first)
        max_font_size   = (sc::max_font_size.first.to_i if sc::max_font_size.first)
        min_font_weight = (sc::min_font_weight.first.to_i if sc::min_font_weight.first)
        max_font_weight = (sc::max_font_weight.first.to_i if sc::max_font_weight.first)
        font_family     =  sc::font_family.first
        attributes      =  sc::attribute
        formats         =  sc::format
        
        doc[:content].search(sc::tag.first || "*").select do |node|
          relative_x = node['vx'].to_i - doc[:content]['vx'].to_i
          relative_y = node['vy'].to_i - doc[:content]['vy'].to_i
          
          !node.text? and
          ( !min_relative_x  or relative_x          >= min_relative_x) and
          ( !max_relative_x  or relative_x          <= max_relative_x) and
          ( !min_relative_y  or relative_y          >= min_relative_y) and
          ( !max_relative_y  or relative_y          <= max_relative_y) and
          
          ( !min_x           or node['vx'].to_i      >= min_x) and
          ( !max_x           or node['vx'].to_i      <= max_x) and
          ( !min_y           or node['vy'].to_i      >= min_y) and
          ( !max_y           or node['vy'].to_i      <= max_y) and
          
          ( !min_width       or node['vw'].to_i      >= min_width) and
          ( !max_width       or node['vw'].to_i      <= max_width) and
          ( !min_height      or node['vh'].to_i      >= min_height) and
          ( !max_height      or node['vh'].to_i      <= max_height) and
          
          ( !min_font_size   or node['vsize'].to_i   >= min_font_size) and
          ( !max_font_size   or node['vsize'].to_i   <= max_font_size) and
          ( !min_font_weight or node['vweight'].to_i >= min_font_weight) and
          ( !max_font_weight or node['vweight'].to_i <= max_font_weight) and
          ( !font_family     or node['vfont']        == font_family)
        end.map do |content|
          if attributes.first
            # Select node's attribute if given
            attributes.map { |attribute| { :uri=>doc[:uri], :content=>content, :value=>content[attribute], :attribute=>attribute } }
          else
            [ { :uri=>doc[:uri], :content=>content, :value=>format(content, formats, doc[:uri]) } ]
          end
        end.flatten
      end
    end
    
  end
end