module Scrappy
  class Dumper
    Mux = Mutex.new

    def self.dump uri, triples, format
      Mux.synchronize do
        filename = uri.gsub("http://", "").gsub("https://", "").gsub("/", "-").gsub(".", "_").gsub("?", "+").gsub("&", "+") + ".#{format}"        
        data = RDF::Graph.new(triples).serialize(format)
        File.open(filename, "w") { |f| f.write data }
      end
    end
  end
end