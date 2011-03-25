$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'nokogiri'
require 'thread'
require 'mechanize'
require 'ostruct'
require 'active_support'
require 'tmpdir'
require 'lightrdf'

Namespace :sc, 'http://lab.gsi.dit.upm.es/scraping.rdf#'

require 'scrappy/support'
require 'scrappy/repository'

require 'scrappy/extractor/extractor'
require 'scrappy/learning/trainer'
require 'scrappy/learning/optimizer'
require 'scrappy/agent/map_reduce'
require 'scrappy/agent/cache'
require 'scrappy/agent/dumper'
require 'scrappy/agent/blind_agent'
require 'scrappy/agent/agent'

module Scrappy
  VERSION = '0.3.4'
end