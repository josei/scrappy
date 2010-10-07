require 'rubygems'
gem 'hoe', '>= 2.1.0'
require 'hoe'
require 'fileutils'
require './lib/scrappy'

Hoe.plugin :newgem

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.spec 'scrappy' do
  self.developer 'Jose Ignacio', 'joseignacio.fernandez@gmail.com'
  self.summary = "Web scraper that allows producing RDF data out of plain web pages"
  self.post_install_message = '**(Optional) Remember to install rbwebkitgtk for visual parsing features**'
  self.rubyforge_name       = self.name
  self.extra_deps         = [['activesupport','>= 2.3.5'], ['markaby', '>= 0.7.1'], ['camping', '= 2.0'], ['nokogiri', '>= 1.4.1'], ['mechanize','>= 1.0.0'], ['lightrdf','>= 0.1']]
end

require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }
