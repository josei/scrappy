module Sc
  class NewUriSelector < Selector
    def filter doc
      contents = if sc::attribute.first
        # Select node's attribute if given
        sc::attribute.map { |attribute| [doc[:content][attribute], attribute] }
      else
        [ [doc[:value], nil] ]
      end
      
      @indexes ||= Hash.new(0)
      prefix = sc::prefix.first.to_s
      prefix = (prefix =~ /\Ahttp/ ? URI::parse(doc[:uri]).merge(prefix).to_s : "#{doc[:uri]}#{prefix}")
      suffix = sc::suffix.first.to_s
      
      contents.map do |content, attribute|
        variable = if sc::sequence.first.to_s=="true" 
          @indexes[prefix] += 1
        else
          if sc::downcase.first.to_s=="true"
            content.to_s.underscore
          else
            content.to_s.wikify
          end
        end
        
        new_uri = "#{prefix}#{variable}#{suffix}"
        
        { :uri=>new_uri, :content=>doc[:content], :value=>new_uri, :attribute=>attribute }
      end
    end
  end
end