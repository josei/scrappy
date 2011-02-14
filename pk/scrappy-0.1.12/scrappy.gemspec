# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{scrappy}
  s.version = "0.1.12"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jose Ignacio"]
  s.date = %q{2011-02-10}
  s.default_executable = %q{scrappy}
  s.description = %q{RDF web scraper}
  s.email = %q{joseignacio.fernandez@gmail.com}
  s.executables = ["scrappy"]
  s.extra_rdoc_files = ["README.rdoc", "bin/scrappy", "lib/js/annotator.js", "lib/scrappy.rb", "lib/scrappy/agent/agent.rb", "lib/scrappy/agent/blind_agent.rb", "lib/scrappy/agent/cache.rb", "lib/scrappy/agent/map_reduce.rb", "lib/scrappy/agent/extractor.rb", "lib/scrappy/agent/visual_agent.rb", "lib/scrappy/proxy.rb", "lib/scrappy/selectors/base_uri.rb", "lib/scrappy/selectors/css.rb", "lib/scrappy/selectors/new_uri.rb", "lib/scrappy/selectors/root.rb", "lib/scrappy/selectors/section.rb", "lib/scrappy/selectors/slice.rb", "lib/scrappy/selectors/uri.rb", "lib/scrappy/selectors/uri_pattern.rb", "lib/scrappy/selectors/xpath.rb", "lib/scrappy/server.rb", "lib/scrappy/shell.rb", "lib/scrappy/support.rb", "lib/scrappy/webkit/webkit.rb"]
  s.files = ["History.txt", "Manifest", "README.rdoc", "Rakefile", "bin/scrappy", "lib/js/annotator.js", "lib/scrappy.rb", "lib/scrappy/agent/agent.rb", "lib/scrappy/agent/blind_agent.rb", "lib/scrappy/agent/cache.rb", "lib/scrappy/agent/map_reduce.rb", "lib/scrappy/agent/extractor.rb", "lib/scrappy/agent/visual_agent.rb", "lib/scrappy/proxy.rb", "lib/scrappy/selectors/base_uri.rb", "lib/scrappy/selectors/css.rb", "lib/scrappy/selectors/new_uri.rb", "lib/scrappy/selectors/root.rb", "lib/scrappy/selectors/section.rb", "lib/scrappy/selectors/slice.rb", "lib/scrappy/selectors/uri.rb", "lib/scrappy/selectors/uri_pattern.rb", "lib/scrappy/selectors/xpath.rb", "lib/scrappy/server.rb", "lib/scrappy/shell.rb", "lib/scrappy/support.rb", "lib/scrappy/webkit/webkit.rb", "test/test_helper.rb", "test/test_scrappy.rb", "scrappy.gemspec"]
  s.homepage = %q{http://github.com/josei/scrappy}
  s.post_install_message = %q{**(Optional) Remember to install rbwebkitgtk for visual parsing features**}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Scrappy", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{scrappy}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Web scraper that allows producing RDF data out of plain web pages}
  s.test_files = ["test/test_helper.rb", "test/test_scrappy.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 2.3.5"])
      s.add_runtime_dependency(%q<markaby>, [">= 0.7.1"])
      s.add_runtime_dependency(%q<camping>, ["= 2.0"])
      s.add_runtime_dependency(%q<nokogiri>, [">= 1.4.1"])
      s.add_runtime_dependency(%q<mechanize>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<lightrdf>, [">= 0.1"])
      s.add_runtime_dependency(%q<mongrel>, [">= 1.1.5"])
      s.add_runtime_dependency(%q<rest-client>, [">= 1.6.1"])
      s.add_runtime_dependency(%q<i18n>, [">= 0.4.2"])
    else
      s.add_dependency(%q<activesupport>, [">= 2.3.5"])
      s.add_dependency(%q<markaby>, [">= 0.7.1"])
      s.add_dependency(%q<camping>, ["= 2.0"])
      s.add_dependency(%q<nokogiri>, [">= 1.4.1"])
      s.add_dependency(%q<mechanize>, [">= 1.0.0"])
      s.add_dependency(%q<lightrdf>, [">= 0.1"])
      s.add_dependency(%q<mongrel>, [">= 1.1.5"])
      s.add_dependency(%q<rest-client>, [">= 1.6.1"])
      s.add_dependency(%q<i18n>, [">= 0.4.2"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 2.3.5"])
    s.add_dependency(%q<markaby>, [">= 0.7.1"])
    s.add_dependency(%q<camping>, ["= 2.0"])
    s.add_dependency(%q<nokogiri>, [">= 1.4.1"])
    s.add_dependency(%q<mechanize>, [">= 1.0.0"])
    s.add_dependency(%q<lightrdf>, [">= 0.1"])
    s.add_dependency(%q<mongrel>, [">= 1.1.5"])
    s.add_dependency(%q<rest-client>, [">= 1.6.1"])
    s.add_dependency(%q<i18n>, [">= 0.4.2"])
  end
end
