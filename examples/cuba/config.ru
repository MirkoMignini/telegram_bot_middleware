require 'cuba'
require_relative '../../lib/telegram_bot_middleware'

Cuba.use TelegramBotMiddleware do |config|
  config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
  config.host = 'http://127.0.0.1:9292'
  config.get_updates = :polling
end

Cuba.define do
  on get do
    on 'hello' do
      res.headers["Content-Type"] = "application/json; charset=utf-8"
      res.write({
        'text' => 'Ciao',
        'reply_markup' => {'keyboard' => [%w(A B), ['C', 'D']], 'resize_keyboard' => true, 'one_time_keyboard' => true, 'selective' => false}
      })
    end
    
    on 'test' do
      res.write({
        'multiple' => [
          {
            'photo' => '../../tmp/test.png',
            'caption' => 'caption'
          },
          {
            'text' => 'Ciao',
            'reply_markup' => {'keyboard' => [%w(A B), ['C', 'D']], 'resize_keyboard' => true, 'one_time_keyboard' => true, 'selective' => false}
          }
        ]
      })
    end
    
    on /.*/ do
      res.write 'Hello world!'
    end
  end
end

warmup do |app|
  client = Rack::MockRequest.new(app)
  client.get('/')
end

run Cuba