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
      if !["http://", "https://"].include?(prefix)
        prefix = (prefix =~ /\Ahttp\:/ or prefix =~ /\Ahttps\:/) ? URI::parse(doc[:uri]).merge(prefix).to_s : "#{doc[:uri]}#{prefix}"
      end
      suffix = sc::suffix.first.to_s
      
      nofollow = (sc::follow.first != "true")
      
      contents.map do |content, attribute|
        new_uri = if (content.to_s =~ /\Ahttp\:/ or content.to_s =~ /\Ahttps\:/)
          "#{content}#{suffix}"
        else
          variable = if sc::sequence.first.to_s=="true" 
            @indexes[prefix] += 1
          else
            if sc::downcase.first.to_s=="true"
              content.to_s.underscore
            else
              content.to_s.wikify
            end
          end
          "#{prefix}#{variable}#{suffix}"
        end
        
        { :uri=>new_uri, :content=>doc[:content], :value=>new_uri, :attribute=>attribute, :nofollow=>nofollow }
      end
    end
  end
end