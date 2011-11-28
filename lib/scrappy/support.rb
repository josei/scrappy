# -*- encoding: utf-8 -*-
require 'iconv'
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
  Utf8Iconv = Iconv.new('UTF-8//IGNORE', 'UTF-8')
  
  def wikify
    gsub(/^[a-z]|\s+[a-z]/) { |a| a.upcase }.gsub(/\s/, '')
  end
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    gsub(/\s+/,"_").
    downcase
  end
  def clean
    Utf8Iconv.iconv(self + '  ')[0..-3].gsub("\302\240"," ").strip
  end
end