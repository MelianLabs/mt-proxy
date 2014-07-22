# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mt/proxy/version'

Gem::Specification.new do |spec|
  spec.name          = "mt-proxy"
  spec.version       = MT::Proxy::VERSION
  spec.authors       = ["Vlad Verestiuc"]
  spec.email         = ["verestiuc.vlad@gmail.com"]
  spec.summary       = %q{MyTime proxy checker and chooser}
  spec.description   = %q{MyTime proxy checker and chooser}
  spec.homepage      = ""
  spec.license       = "MIT"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", "~> 3.0.1"
  spec.add_dependency "hiredis", "~> 0.4.5"
  spec.add_dependency "activesupport"
  spec.add_dependency "redis-namespace"
  spec.add_dependency "thor"



  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-bundler'
  spec.add_development_dependency 'guard-pow'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'mock_redis'
  spec.add_development_dependency "timecop"

end
