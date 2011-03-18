module Sc
  class VisualSelector < Selector
    def filter doc
      doc[:content].search(sc::tag.first || "*").select do |node|
        relative_x = node['vx'].to_i - doc[:content]['vx'].to_i
        relative_y = node['vy'].to_i - doc[:content]['vy'].to_i
        
        !node.text? and
        ( !sc::min_relative_x.first  or relative_x          >= sc::min_relative_x.first.to_i) and
        ( !sc::max_relative_x.first  or relative_x          <= sc::max_relative_x.first.to_i) and
        ( !sc::min_relative_y.first  or relative_y          >= sc::min_relative_y.first.to_i) and
        ( !sc::max_relative_y.first  or relative_y          <= sc::max_relative_y.first.to_i) and
        
        ( !sc::min_x.first           or node['vx'].to_i      >= sc::min_x.first.to_i) and
        ( !sc::max_x.first           or node['vx'].to_i      <= sc::max_x.first.to_i) and
        ( !sc::min_y.first           or node['vy'].to_i      >= sc::min_y.first.to_i) and
        ( !sc::max_y.first           or node['vy'].to_i      <= sc::max_y.first.to_i) and
        
        ( !sc::min_width.first       or node['vw'].to_i      >= sc::min_width.first.to_i) and
        ( !sc::max_width.first       or node['vw'].to_i      <= sc::max_width.first.to_i) and
        ( !sc::min_height.first      or node['vh'].to_i      >= sc::min_height.first.to_i) and
        ( !sc::max_height.first      or node['vh'].to_i      <= sc::max_height.first.to_i) and
        
        ( !sc::min_font_size.first   or node['vsize'].to_i   >= sc::min_font_size.first.to_i) and
        ( !sc::max_font_size.first   or node['vsize'].to_i   <= sc::max_font_size.first.to_i) and
        ( !sc::min_font_weight.first or node['vweight'].to_i >= sc::min_font_weight.first.to_i) and
        ( !sc::max_font_weight.first or node['vweight'].to_i <= sc::max_font_weight.first.to_i) and
        ( !sc::font_family.first     or node['vfont']        == sc::font_family.first)
      end.map do |content|
        if sc::attribute.first
          # Select node's attribute if given
          sc::attribute.map { |attribute| { :uri=>doc[:uri], :content=>content, :value=>content[attribute] } }
        else
          [ { :uri=>doc[:uri], :content=>content, :value=>format(content, sc::format, doc[:uri]) } ]
        end
      end.flatten
    end
  end
end