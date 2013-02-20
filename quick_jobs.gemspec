# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'quick_jobs/version'

Gem::Specification.new do |gem|
  gem.name          = "quick_jobs"
  gem.version       = QuickJobs::VERSION
  gem.authors       = ["Alan Graham"]
  gem.email         = ["alan@productlab.com"]
  gem.description   = %q{Delayed jobs library for Ruby}
  gem.summary       = %q{Delayed jobs library for Ruby}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
