require 'rubygems'
require 'rake'
require 'echoe'
require './lib/scrappy'

Echoe.new('scrappy', Scrappy::VERSION) do |p|
  p.description    = "RDF web scraper"
  p.summary        = "Web scraper that allows producing RDF data out of plain web pages"
  p.url            = "http://github.com/josei/scrappy"
  p.author         = "Jose Ignacio"
  p.email          = "joseignacio.fernandez@gmail.com"
  p.ignore_pattern = ["pkg/*"]
  p.development_dependencies = [['activesupport','>= 2.3.5'], ['markaby', '>= 0.7.1'], ['camping', '= 2.0'], ['nokogiri', '>= 1.4.1'], ['mechanize','>= 1.0.0'], ['lightrdf','>= 0.1'], ['mongrel', '>= 1.1.5']]
end

Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_files.include('README.rdoc').include('lib/**/*.rb')
  rdoc.main = "README.rdoc"
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each
