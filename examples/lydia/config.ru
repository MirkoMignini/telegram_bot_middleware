$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'lydia/application'
require 'telegram_bot_middleware'

class Application < Lydia::Application

  use TelegramBotMiddleware do |config|
    config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
    config.host = 'http://127.0.0.1:9292'
    config.get_updates = :polling
  end
  
  get '/hello' do
    'Hello world!'
  end
  
  get '/json' do
    {
      text: "Hello #{params['from']['first_name']} #{params['from']['last_name']}!",
      reply_markup: {keyboard: [%w(A B), ['C', 'D']], resize_keyboard: true, one_time_keyboard: true, selective: false}
    }
  end
end

warmup do |app|
  client = Rack::MockRequest.new(app)
  client.get('/')
end

run Application.new
