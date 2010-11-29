$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'nokogiri'
require 'thread'
require 'mechanize'
require 'ostruct'
require 'active_support'
require 'tmpdir'
require 'lightrdf'

require 'scrappy/support'

require 'scrappy/agent/extractor'
require 'scrappy/agent/map_reduce'
require 'scrappy/agent/cache'
require 'scrappy/agent/agent'

Namespace :sc, 'http://lab.gsi.dit.upm.es/scraping.rdf#'

module Scrappy
  VERSION = '0.1.5'
end

# Require selectors
Dir["#{File.expand_path(File.dirname(__FILE__))}/scrappy/selectors/*.rb"].each { |f| require f }
