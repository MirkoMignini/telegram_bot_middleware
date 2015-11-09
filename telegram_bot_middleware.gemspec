# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'telegram_bot_middleware/version'

Gem::Specification.new do |spec|
  spec.name          = "telegram_bot_middleware"
  spec.version       = TelegramBotMiddleware::VERSION
  spec.authors       = ["Mirko Mignini"]
  spec.email         = ["mirko.mignini@gmail.com"]

  spec.summary       = %q{Rack middleware to communicate with a telegram bot.}
  spec.homepage      = 'https://github.com/MirkoMignini/telegram_bot_middleware'
  spec.license       = 'MIT'
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  spec.add_dependency 'rake', '~> 10.0'
  spec.add_dependency 'http'
  spec.add_dependency 'httmultiparty'
  spec.add_dependency 'persistent_httparty'
  
  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rspec'
end