lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'danbooru/version'

Gem::Specification.new do |spec|
  spec.name          = "ruby-booru"
  spec.version       = Danbooru::VERSION
  spec.authors       = ["evazion"]
  spec.email         = ["noizave@gmail.com"]

  spec.summary       = "A Ruby interface for the Danbooru API."
  spec.homepage      = "https://github.com/evazion/ruby-booru.git"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = %w[danbooru]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '~> 2.4'

  spec.add_runtime_dependency "activesupport", "~> 6"
  spec.add_runtime_dependency "addressable", "~> 2"
  spec.add_runtime_dependency "connection_pool", "~> 2"
  spec.add_runtime_dependency "dotenv", "~> 2"
  spec.add_runtime_dependency "dtext_rb", "~> 1"
  spec.add_runtime_dependency "http", "~> 4"
  spec.add_runtime_dependency "retriable", "~> 3"

  spec.add_development_dependency "bundler", "~> 2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "pry-byebug", "~> 3.4"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "shoulda", "~> 3.5"
  spec.add_development_dependency "simplecov", "~> 0.15"
  spec.add_development_dependency "mocha", "~> 1.3"
end
