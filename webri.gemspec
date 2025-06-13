
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'webri/version'

Gem::Specification.new do |spec|
  spec.name          = 'webri'
  spec.version       = WebRI::VERSION
  spec.authors       = ['burdettelamar']
  spec.email         = ['burdettelamar@yahoo.com']
  spec.summary       = 'Command-line utility to display Ruby online documentation.'
  spec.description   = 'Command-line utility to display Ruby online documentation'
  spec.homepage      = 'https://github.com/BurdetteLamar/webri'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|html)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = ['webri']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake', '~> 12.3.2'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
