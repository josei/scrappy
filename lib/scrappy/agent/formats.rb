module Scrappy
  module Formats

    def format node, formats
      case formats.first
      when Node('sc:WikiText') then
        doc = Nokogiri::XML(node.to_html)
        doc.search("h1").each {|n| n.replace(Nokogiri::XML::Text.new("= #{n.text.strip} =", n.document)) }
        doc.search("h2").each {|n| n.replace(Nokogiri::XML::Text.new("== #{n.text.strip} ==", n.document)) }
        doc.search("h3").each {|n| n.replace(Nokogiri::XML::Text.new("=== #{n.text.strip} ===", n.document)) }
        doc.search("h4").each {|n| n.replace(Nokogiri::XML::Text.new("==== #{n.text.strip} ====", n.document)) }
        doc.search("h5").each {|n| n.replace(Nokogiri::XML::Text.new("===== #{n.text.strip} =====", n.document)) }
        doc.search("b").each  {|n| n.replace(Nokogiri::XML::Text.new("'''#{n.text.strip}'''", n.document)) }
        doc.search("li").each {|n| n.replace(Nokogiri::XML::Text.new("* #{n.text.strip}", n.document)) }
        doc.search("ul").each {|n| n.replace(Nokogiri::XML::Text.new(n.text.strip, n.document)) }
        doc.search("pre, code").each {|n| n.replace(Nokogiri::XML::Text.new("<pre>\n#{n.text.strip}\n</pre>", n.document)) }
        doc.search("p").each {|n| n.replace(Nokogiri::XML::Text.new("#{n.text.strip}\n", n.document)) }
        doc.text.strip
      when Node('sc:Html') then
        node.to_html
      else
        node.text
      end
    end

  end
end