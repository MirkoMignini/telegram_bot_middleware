require 'lydia/application'
require_relative '../../lib/telegram_bot_middleware'

class Application < Lydia::Application

  use TelegramBotMiddleware do |config|
    config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
    config.host = 'http://127.0.0.1:9292'
    config.get_updates = :polling
  end
  
  get '/hello' do
    'Hello world!'
  end
end

warmup do |app|
  client = Rack::MockRequest.new(app)
  client.get('/')
end

run Application