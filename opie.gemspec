# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'opie/version'

Gem::Specification.new do |spec|
  spec.name          = 'opie'
  spec.version       = Opie::VERSION
  spec.authors       = ['Arturo Guzman']
  spec.email         = ['arturo@guzart.com']

  spec.summary       = 'Operations API for Railway oriented programming in Ruby'
  spec.description   = <<~DOC
    Opie provides an API for building your application operations/transactions using
    the Railway oriented programming paradigm
  DOC
  spec.homepage      = 'https://github.com/guzart/opie'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'awesome_print', '~> 1.7'
  spec.add_development_dependency 'byebug', '~> 9.0'
  spec.add_development_dependency 'codecov', '~> 0'
  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'guard', '~> 2.14'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.5'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
