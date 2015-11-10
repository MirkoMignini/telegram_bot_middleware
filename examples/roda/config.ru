require 'roda'
require_relative '../../lib/telegram_bot_middleware'

class App < Roda
  use TelegramBotMiddleware do |config|
    config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
    config.host = 'http://127.0.0.1:9292'
    config.get_updates = :polling
  end
  
  #plugin :json

  route do |r|
    
    r.on 'hello' do
      {
        text: 'Ciao',
        reply_markup: {keyboard: [%w(A B), ['C', 'D']], resize_keyboard: true, one_time_keyboard: true, selective: false}
      }
    end
    
    r.on 'image' do
      {
        photo: File.new('../../tmp/test.png'),
        caption: 'caption'
      }
    end
    
    r.on /.*/ do
      'Hello world!'
    end
  end
end

warmup do |app|
  client = Rack::MockRequest.new(app)
  client.get('/')
end

run App.freeze.app