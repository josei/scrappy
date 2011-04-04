require 'open-uri'
require 'net/http'
require 'net/https'

module URI
  def base
    self.to_s.split('/')[0..2] * '/'
  end
end

module Nokogiri
  module XML
    class NodeSet
      def select &block
        NodeSet.new(document, super(&block))
      end
    end
  end
end

class String
  def wikify
    gsub(/^[a-z]|\s+[a-z]/) { |a| a.upcase }.gsub(/\s/, '')
  end
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end