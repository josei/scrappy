module Scrappy
  module Formats

    def format node, formats, uri
      case formats.first
      when Node('sc:WikiText') then
        doc = Nokogiri::XML(node.to_html)
        doc.search("a").each {|n| n.replace(Nokogiri::XML::Text.new(URI.parse(uri).merge(n["href"]).to_s, n.document)) }
        doc.search("h1").each {|n| n.replace(Nokogiri::XML::Text.new("= #{n.text.strip} =", n.document)) }
        doc.search("h2").each {|n| n.replace(Nokogiri::XML::Text.new("== #{n.text.strip} ==", n.document)) }
        doc.search("h3").each {|n| n.replace(Nokogiri::XML::Text.new("=== #{n.text.strip} ===", n.document)) }
        doc.search("h4").each {|n| n.replace(Nokogiri::XML::Text.new("==== #{n.text.strip} ====", n.document)) }
        doc.search("h5").each {|n| n.replace(Nokogiri::XML::Text.new("===== #{n.text.strip} =====", n.document)) }
        doc.search("b").each  {|n| n.replace(Nokogiri::XML::Text.new("'''#{n.text.strip}'''", n.document)) }
        doc.search("td").each     {|n| n.replace(Nokogiri::XML::Text.new("<td>#{n.text.strip}</td>", n.document)) }
        doc.search("tr").each     {|n| n.replace(Nokogiri::XML::Text.new("<tr>#{n.text.strip}</tr>", n.document)) }
        doc.search("table").each  {|n| n.replace(Nokogiri::XML::Text.new("<table>#{n.text.strip}</table>", n.document)) }        
        doc.search("li li li li li").each {|n| n.replace(Nokogiri::XML::Text.new("***** #{n.text.strip}", n.document)) }
        doc.search("li li li li").each {|n| n.replace(Nokogiri::XML::Text.new("**** #{n.text.strip}", n.document)) }
        doc.search("li li li").each {|n| n.replace(Nokogiri::XML::Text.new("*** #{n.text.strip}", n.document)) }
        doc.search("li li").each {|n| n.replace(Nokogiri::XML::Text.new("** #{n.text.strip}", n.document)) }
        doc.search("li").each {|n| n.replace(Nokogiri::XML::Text.new("* #{n.text.strip}", n.document)) }
        doc.search("ul").each {|n| n.replace(Nokogiri::XML::Text.new(n.text.strip, n.document)) }
        doc.search("pre, code").each {|n| n.replace(Nokogiri::XML::Text.new("<pre>#{n.text}</pre>", n.document)) }
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