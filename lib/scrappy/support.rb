require 'open-uri'
require 'net/http'
require 'net/https'

module URI
  def base
    self.to_s.split('/')[0..2] * '/'
  end
end

module Scrappy
  module InputEscaping
    def inputs
      return '' if @input.empty?
      "?" + (@input.map{|k,v| "#{CGI.escape(k)}=#{CGI.escape(v)}"}*'')
    end
  end
end

class RDF::Node
  def hash
    id.hash ^ self.class.hash
  end
end
